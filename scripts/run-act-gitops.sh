#!/usr/bin/env bash
# Run the same GitHub Actions job locally with act (Docker).
# Uses the same dedicated hm-gitops SSH key as GitHub Actions (not your primary ~/.ssh/id_*).
#
#   ./scripts/run-act-gitops.sh
#
# Requires ~/.ssh/hm-gitops (same key as GITOPS_DEPLOY_KEY / GITOPS_DEPLOY_KEY_B64 on GitHub).
#
# Optional: GITOPS_BECOME_PASSWORD (or NOPASSWD on the VPS).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY_FILE="$HOME/.ssh/hm-gitops"
if [[ ! -f "$KEY_FILE" ]]; then
  echo "Missing $KEY_FILE" >&2
  echo "Create one (separate from your primary ~/.ssh/id_*): ./scripts/new-hm-gitops-key.sh" >&2
  exit 1
fi
if [[ ! -f "$ROOT/local-env.yaml" ]]; then
  echo "Missing $ROOT/local-env.yaml (copy from local-env.example.yaml)" >&2
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
  -s "GITOPS_DEPLOY_KEY_B64=${KEY_B64}"
)
if [[ -n "${GITOPS_BECOME_PASSWORD:-}" ]]; then
  ACT_ARGS+=(-s "GITOPS_BECOME_PASSWORD=${GITOPS_BECOME_PASSWORD}")
fi
if [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 && -z "${ACT_SKIP_CONTAINER_ARCH:-}" ]]; then
  ACT_ARGS+=(--container-architecture linux/amd64)
fi

exec act "${ACT_ARGS[@]}" "$@"
