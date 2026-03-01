#!/usr/bin/env bash
set -euo pipefail

log() { printf '[hackamonth-init] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

REPO_URL="${REPO_URL:-https://github.com/sidosera/machine-gitops.git}"
BRANCH="${BRANCH:-main}"
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"

# --- packages ---

sudo apt-get update -y
sudo apt-get install -y git curl ufw fail2ban unattended-upgrades

# --- k3s ---

if ! command -v k3s >/dev/null 2>&1; then
  log "Installing k3s"
  curl -sfL https://get.k3s.io | sh -s - --disable=servicelb --write-kubeconfig-mode=644
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

log "Waiting for node"
for _ in $(seq 1 30); do
  k3s kubectl get nodes 2>/dev/null | grep -q ' Ready' && break
  sleep 2
done
k3s kubectl get nodes | grep -q ' Ready' || die "k3s not ready"

# --- cert-manager ---

if ! k3s kubectl get ns cert-manager >/dev/null 2>&1; then
  log "Installing cert-manager"
  k3s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
  k3s kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s
fi

# --- argocd ---

if ! k3s kubectl get ns argocd >/dev/null 2>&1; then
  log "Installing ArgoCD"
  k3s kubectl create namespace argocd
  k3s kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
  k3s kubectl wait --for=condition=Available deployment --all -n argocd --timeout=180s
fi

# --- argocd app pointing at this repo ---

k3s kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hackamonth
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${BRANCH}
    path: k8s
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# --- harden ---

sudo ufw allow OpenSSH >/dev/null
sudo ufw allow 80/tcp  >/dev/null
sudo ufw allow 443/tcp >/dev/null
sudo ufw allow 6443/tcp >/dev/null
sudo ufw --force enable >/dev/null
sudo systemctl enable --now fail2ban
sudo dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null || true

sudo tee /etc/ssh/sshd_config.d/99-hackamonth.conf >/dev/null <<'EOF'
PasswordAuthentication no
X11Forwarding no
MaxAuthTries 3
EOF
sudo systemctl reload ssh

log "Done."
log "  ArgoCD UI: k3s kubectl port-forward svc/argocd-server -n argocd 8080:443"
log "  Password : k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
log "  Apps     : k3s kubectl get applications -n argocd"
