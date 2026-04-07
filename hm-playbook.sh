#!/usr/bin/env bash
# Usage:
#   HM_LOCAL_ENV=/path/to/local-env.yaml ./hm-playbook.sh [ansible-playbook args...]
# Defaults HM_LOCAL_ENV to ./local-env.yaml when unset.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# pip install --user ansible (macOS/Linux): ensure ansible-playbook is on PATH
if command -v python3 >/dev/null 2>&1; then
  _ub="$(python3 -c "import site; print(site.getuserbase() + '/bin')" 2>/dev/null)" || true
  if [[ -n "${_ub:-}" && -d "$_ub" ]]; then
    PATH="${_ub}:$PATH"
    export PATH
  fi
fi
export HM_LOCAL_ENV="${HM_LOCAL_ENV:-$ROOT/local-env.yaml}"

if [[ ! -f "$HM_LOCAL_ENV" ]]; then
  echo "Missing secrets file: $HM_LOCAL_ENV (set HM_LOCAL_ENV or create local-env.yaml)" >&2
  exit 2
fi

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-$ROOT/ansible/ansible.cfg}"
cd "$ROOT"

exec ansible-playbook \
  -i "$ROOT/ansible/inventory/localhost.yml" \
  "$ROOT/ansible/playbook.yml" \
  -e "local_env_yaml_src=$HM_LOCAL_ENV" \
  "$@"
