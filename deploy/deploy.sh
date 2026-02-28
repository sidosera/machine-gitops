#!/usr/bin/env bash
set -euo pipefail

log() { printf '%s %s\n' "[hackamonth-deploy]" "$*"; }
die() { printf '%s %s\n' "[hackamonth-deploy][ERROR]" "$*" >&2; exit 1; }

LOCK_FILE="/var/lock/hackamonth-deploy.lock"
STATE_DIR="${STATE_DIR:-/var/lib/hackamonth}"
LAST_GOOD="$STATE_DIR/last_good_sha"

mkdir -p "$STATE_DIR"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another deploy is running, exiting"
  exit 0
fi

: "${INSTALL_DIR:?missing INSTALL_DIR}"
: "${BRANCH:?missing BRANCH}"
: "${DOMAIN:?missing DOMAIN}"

cd "$INSTALL_DIR"

log "Fetching desired state (origin/$BRANCH)"
git fetch --prune origin

CURRENT_SHA="$(git rev-parse HEAD)"
TARGET_SHA="$(git rev-parse "origin/$BRANCH")"

CHANGED=0
if [ "$CURRENT_SHA" != "$TARGET_SHA" ]; then
  log "Updating $CURRENT_SHA -> $TARGET_SHA"
  git reset --hard "origin/$BRANCH"
  CHANGED=1
else
  log "Already at desired revision $CURRENT_SHA"
fi

log "Validating compose config"
docker compose config >/dev/null

if [ "$CHANGED" = "1" ]; then
  log "Pulling images"
  docker compose pull
fi

log "Applying compose"
docker compose up -d --remove-orphans

# Health probe with retries — Traefik needs a moment to register routes after start.
PROBE_OK=0
for i in 1 2 3 4 5; do
  if curl --max-time 10 -fsS -H "Host: $DOMAIN" "http://127.0.0.1/" >/dev/null 2>&1; then
    PROBE_OK=1
    break
  fi
  log "Health probe attempt $i/5 failed, retrying in 3s..."
  sleep 3
done

if [ "$PROBE_OK" = "1" ]; then
  log "Health probe OK for $DOMAIN"
else
  log "Health probe FAILED after 5 attempts; attempting rollback"
  if [ -f "$LAST_GOOD" ]; then
    GOOD_SHA="$(cat "$LAST_GOOD")"
    log "Rolling back to $GOOD_SHA"
    git reset --hard "$GOOD_SHA"
    docker compose config >/dev/null
    docker compose pull
    docker compose up -d --remove-orphans
    sleep 5
    curl --max-time 10 -fsS -H "Host: $DOMAIN" "http://127.0.0.1/" >/dev/null || die "Rollback failed health probe"
    log "Rollback succeeded"
    exit 1
  else
    die "No last_good_sha recorded; cannot rollback"
  fi
fi

echo "$(git rev-parse HEAD)" > "$LAST_GOOD"
log "Recorded last good revision: $(cat "$LAST_GOOD")"

log "Deploy complete"