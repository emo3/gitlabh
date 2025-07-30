#!/bin/bash
set -e

echo "=== GitLab Local Installation Script (Minikube + Helm) ==="
echo ""

# Configuration variables
NAMESPACE="gitlab"
RELEASE_NAME="gitlab"
VALUES_FILE="minimal-values.yaml"
DOMAIN="gitlab.localhost"
TIMEOUT="10m"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "--- Step 1: Prerequisites Check ---"
print_status "Checking prerequisites..."

if ! command_exists kubectl; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command_exists helm; then
    print_error "helm not found. Please install helm first."
    exit 1
fi

if ! command_exists minikube; then
    print_error "minikube not found. Please install minikube first."
    exit 1
fi

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
    print_error "Minikube is not running. Please start minikube first:"
    echo "  minikube start --memory=8192 --cpus=4 --driver=docker"
    exit 1
fi

print_success "All prerequisites met"
echo ""

# Check for values file
echo "--- Step 2: Configuration Check ---"
if [ ! -f "$VALUES_FILE" ]; then
    print_error "Missing '$VALUES_FILE' in current directory."
    print_status "Expected file content:"
    cat << 'EOF'
global:
  edition: ce
  hosts:
    domain: localhost
    externalIP: 192.168.49.2 
    https: false
  ingress:
    configureCertmanager: false
    class: nginx
    annotations: {}

nginx-ingress:
  enabled: true
  controller:
    service:
      type: NodePort

gitlab:
  webservice:
    replicas: 1

redis:
  install: true

postgresql:
  install: true
EOF
    exit 1
fi
print_success "Configuration file '$VALUES_FILE' found"
echo ""

# Add GitLab Helm repo
echo "--- Step 3: Helm Repository Setup ---"
print_status "Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1
print_success "GitLab Helm repository updated"
echo ""

# Install GitLab
echo "--- Step 4: Install GitLab Helm Chart ---"
print_status "Installing GitLab (this may take several minutes)..."

if ! helm upgrade --install "$RELEASE_NAME" gitlab/gitlab \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --create-namespace \
  --timeout "$TIMEOUT"; then
  print_error "Failed to install GitLab. Check the logs above for details."
  print_status "You can check pod status with: kubectl get pods -n $NAMESPACE"
  exit 1
fi
print_success "GitLab Helm chart installed"
echo ""

# Wait for pods to be ready
echo "--- Step 5: Wait for GitLab Pods to be Ready ---"
print_status "Waiting for GitLab pods to be ready (this can take 5-15 minutes)..."

# Custom wait logic since we don't have wait.sh
max_attempts=120  # 10 minutes with 5-second intervals
attempt=0

while [ $attempt -lt $max_attempts ]; do
    # Count running pods (excluding the runner which may crash)
    running_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
        grep -v "gitlab-runner" | \
        grep -E "(Running|Completed)" | \
        wc -l || echo "0")
    
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
        grep -v "gitlab-runner" | \
        wc -l || echo "0")
    
    if [ "$total_pods" -gt 0 ] && [ "$running_pods" -eq "$total_pods" ]; then
        print_success "All GitLab pods are ready ($running_pods/$total_pods)"
        break
    fi
    
    if [ $((attempt % 12)) -eq 0 ]; then  # Print status every minute
        print_status "Still waiting... ($running_pods/$total_pods pods ready)"
    fi
    
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    print_warning "Timeout waiting for all pods to be ready. Current status:"
    kubectl get pods -n "$NAMESPACE"
    print_status "GitLab may still be starting up. You can continue with the setup."
fi
echo ""

# Configure host mapping
echo "--- Step 6: Configure Host Mapping ---"
if ! grep -q "$DOMAIN" /etc/hosts 2>/dev/null; then
    print_status "Adding $DOMAIN to /etc/hosts..."
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts >/dev/null
    print_success "Added $DOMAIN to /etc/hosts"
else
    print_status "$DOMAIN already exists in /etc/hosts"
fi
echo ""

# Get minikube service URLs
echo "--- Step 7: Service Access Setup ---"
print_status "Getting service access URLs..."
print_warning "Starting minikube service tunnel (keep this running)..."
echo ""
print_status "Run this command in a separate terminal to get access URLs:"
echo "  minikube service gitlab-nginx-ingress-controller -n $NAMESPACE --url"
echo ""

# Get initial password
echo "--- Step 8: Get Login Credentials ---"
print_status "Retrieving root password..."
if kubectl get secret gitlab-gitlab-initial-root-password -n "$NAMESPACE" >/dev/null 2>&1; then
    ROOT_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null || echo "Unable to decode")
    print_success "Root password retrieved"
else
    ROOT_PASSWORD="Unable to retrieve - secret not found"
    print_warning "Could not retrieve root password automatically"
fi
echo ""

# Final instructions
echo "🎉 GitLab Installation Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Run this command in a NEW terminal (keep it open):"
echo "   minikube service gitlab-nginx-ingress-controller -n $NAMESPACE --url"
echo ""
echo "2. Note the HTTPS port from the output (e.g., https://127.0.0.1:55708)"
echo ""
echo "3. Access GitLab in your browser:"
echo "   https://$DOMAIN:[HTTPS_PORT_FROM_STEP_1]"
echo ""
echo "4. Login credentials:"
echo "   Username: root"
echo "   Password: $ROOT_PASSWORD"
echo ""
echo "⚠️  Important Notes:"
echo "   - Keep the minikube service terminal open while using GitLab"
echo "   - Your browser will show a security warning (click Advanced → Proceed)"
echo "   - The HTTPS port changes each time you restart the service tunnel"
echo ""
echo "🔧 Troubleshooting:"
echo "   - Check pods: kubectl get pods -n $NAMESPACE"
echo "   - Check ingress: kubectl get ingress -n $NAMESPACE"
echo "   - View logs: kubectl logs -n $NAMESPACE -l app=webservice"
echo ""

# Optional: Start service tunnel automatically
read -p "Start the minikube service tunnel now? (y/n): " start_tunnel
if [[ "$start_tunnel" == "y" ]]; then
    print_status "Starting service tunnel..."
    print_warning "This will keep running - press Ctrl+C when done with GitLab"
    minikube service gitlab-nginx-ingress-controller -n "$NAMESPACE" --url
fi
