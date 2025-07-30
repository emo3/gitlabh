#!/bin/bash

set -e

# Configuration
NAMESPACE="gitlab"
HELM_RELEASE="gitlab"
HOSTNAME="gitlab.localhost"
HOST_ENTRY="127.0.0.1 $HOSTNAME"
HOSTS_FILE="/etc/hosts"
HTTP_PORT=8080  # Local port for HTTP access
HTTPS_PORT=8443 # Local port for HTTPS access

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_section() {
    echo ""
    echo "--- $1 ---"
}

echo "=== GitLab Local Installation Script (Minikube + Helm) ==="

print_section "Step 1: Quick Validation"
print_status "Verifying environment is ready..."

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
    print_error "Minikube is not running. Please start it first:"
    echo "  minikube start --memory=8192 --cpus=4 --driver=docker"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    print_error "kubectl is not available. Please install it first."
    exit 1
fi

# Check if helm is available
if ! command -v helm >/dev/null 2>&1; then
    print_error "helm is not available. Please install it first."
    exit 1
fi

print_success "Environment validated"

print_section "Step 2: Install GitLab Helm Chart"
print_status "Installing GitLab (this may take several minutes)..."

# Add GitLab Helm repository if not already added
helm repo add gitlab https://charts.gitlab.io/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

print_status "Creating namespace if it doesn't exist..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

print_status "Creating dummy backup secret..."
kubectl create secret generic dummy-backup-secret \
  --from-literal=config="{}" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Shared Helm values
HELM_VALUES=(
  --namespace "$NAMESPACE"
  --set global.hosts.domain=localhost
  --set global.hosts.externalIP=127.0.0.1
  --set certmanager.install=false
  --set certmanager-issuer.email=dummy@example.com
  --set global.ingress.tls.enabled=false
  --set global.ingress.configureCertmanager=false
  --set gitlab-runner.install=true
  -f    minimal-values.yaml
)

helm upgrade --install "$HELM_RELEASE" gitlab/gitlab \
  "${HELM_VALUES[@]}"

print_success "GitLab Helm chart installed"

print_section "Step 3: Wait for GitLab Pods to be Ready"
print_status "Waiting for GitLab pods to be ready (this can take 5-15 minutes)..."

# Use the improved wait script logic
./wait-gitlab.sh

print_section "Step 4: Configure Host Mapping"
print_status "Checking gitlab.localhost in /etc/hosts..."

if ! grep -q "$HOST_ENTRY" "$HOSTS_FILE"; then
    print_status "Adding gitlab.localhost to /etc/hosts..."
    echo "$HOST_ENTRY" | sudo tee -a "$HOSTS_FILE" >/dev/null
    print_success "Added gitlab.localhost to /etc/hosts"
else
    print_success "gitlab.localhost already in /etc/hosts"
fi

print_section "Step 5: Port Forwarding"
print_status "Setting up port forwarding for GitLab..."
print_status "In ANOTHER TERMINAL, run the following command to access GitLab:"
# Start port forwarding
print_status "kubectl port-forward service/gitlab-nginx-ingress-controller -n "$NAMESPACE" $HTTP_PORT:80"

# Wait a moment to ensure port forwarding is established
sleep 5
print_status "Access GitLab at http://gitlab.localhost:8080"
