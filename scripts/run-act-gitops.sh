#!/usr/bin/env bash
# Run the same GitHub Actions job locally with act (Docker).
# Requires: Docker, act (https://github.com/nektos/act), ./local-env.yaml, SSH key.
#
#   ./scripts/run-act-gitops.sh
#   GITOPS_SSH_KEY_FILE=~/.ssh/my_key ./scripts/run-act-gitops.sh --dryrun
#
# Optional: export GITOPS_BECOME_PASSWORD for sudo on the VPS (same as GitHub secret).
# Or configure NOPASSWD for your deploy user so this is unset.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY_FILE="${GITOPS_SSH_KEY_FILE:-$HOME/.ssh/id_ed25519}"
if [[ ! -f "$ROOT/local-env.yaml" ]]; then
  echo "Missing $ROOT/local-env.yaml (copy from local-env.example.yaml)" >&2
  exit 1
fi
if [[ ! -f "$KEY_FILE" ]]; then
  echo "Missing SSH private key: $KEY_FILE (set GITOPS_SSH_KEY_FILE)" >&2
  exit 1
fi
if ! command -v act >/dev/null 2>&1; then
  echo "Install act: brew install act  (or see https://github.com/nektos/act)" >&2
  exit 1
fi

ENV_B64=$(base64 <"$ROOT/local-env.yaml" | tr -d '\n')
KEY_B64=$(base64 <"$KEY_FILE" | tr -d '\n')

ACT_PLATFORM="${ACT_PLATFORM:-catthehacker/ubuntu:act-22.04}"

ACT_ARGS=(
  workflow_dispatch
  --workflows .github/workflows/gitops-apply.yml
  --job ansible-update
  -P "ubuntu-latest=${ACT_PLATFORM}"
  -s "GITOPS_LOCAL_ENV_B64=${ENV_B64}"
  -s "GITOPS_SSH_KEY_B64=${KEY_B64}"
)
if [[ -n "${GITOPS_BECOME_PASSWORD:-}" ]]; then
  ACT_ARGS+=(-s "GITOPS_BECOME_PASSWORD=${GITOPS_BECOME_PASSWORD}")
fi
# Apple Silicon: catthehacker images are often amd64-only
if [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 && -z "${ACT_SKIP_CONTAINER_ARCH:-}" ]]; then
  ACT_ARGS+=(--container-architecture linux/amd64)
fi

exec act "${ACT_ARGS[@]}" "$@"
