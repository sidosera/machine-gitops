#!/usr/bin/env bash
# Create the dedicated SSH key for this project: same key for local hm-playbook, act, and GitHub Actions.
# Use a different key from your primary ~/.ssh/id_* (used for other private hosts).
#
#   ./scripts/new-hm-gitops-key.sh
#   ./scripts/new-hm-gitops-key.sh ~/.ssh/hm-gitops
#
# Then install the public half on the VPS and upload the private half to GitHub:
#   gh secret set GITOPS_DEPLOY_KEY < ~/.ssh/hm-gitops

set -euo pipefail
KEY="${1:-$HOME/.ssh/hm-gitops}"
if [[ -f "$KEY" ]]; then
  echo "Refusing to overwrite existing key: $KEY" >&2
  exit 1
fi
mkdir -p "$(dirname "$KEY")"
ssh-keygen -t ed25519 -f "$KEY" -C "hm-gitops" -N ""
chmod 600 "$KEY"
echo "Private: $KEY"
echo "Public:  $KEY.pub"
echo ""
echo "1) On the VPS (as secrets.deploy.ssh_user), add this line to ~/.ssh/authorized_keys:"
echo "----"
cat "$KEY.pub"
echo "----"
echo ""
echo "2) Use this key from your laptop (SSH config IdentityFile, or --private-key $KEY)."
echo ""
echo "3) Same private key in GitHub (not your primary id_*):"
echo "   gh secret set GITOPS_DEPLOY_KEY < $KEY"
