#!/bin/bash

set -e

# Configuration
NAMESPACE="gitlab"
HELM_RELEASE="gitlab"
HOSTNAME="gitlab.localhost"
HOST_ENTRY="127.0.0.1 $HOSTNAME"
HOSTS_FILE="/etc/hosts"
SERVICE_TIMEOUT=15

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

# Function to get service URLs with timeout
get_service_urls() {
    print_status "Discovering GitLab service ports (timeout: ${SERVICE_TIMEOUT}s)..."
    
    # Try to get URLs with timeout
    local urls
    urls=$(timeout $SERVICE_TIMEOUT minikube service gitlab-nginx-ingress-controller -n "$NAMESPACE" --url 2>/dev/null || echo "")
    
    if [ -n "$urls" ]; then
        echo "$urls"
        return 0
    else
        return 1
    fi
}

# Function to extract ports from URLs
extract_ports() {
    local urls="$1"
    local http_port=""
    local https_port=""
    
    # Extract HTTP port
    http_port=$(echo "$urls" | grep -E "^http://.*:[0-9]+$" | head -1 | sed 's/.*://')
    
    # Extract HTTPS port  
    https_port=$(echo "$urls" | grep -E "^https://.*:[0-9]+$" | head -1 | sed 's/.*://')
    
    echo "$http_port,$https_port"
}

# Function to test port connectivity
test_port() {
    local port="$1"
    if [ -n "$port" ] && nc -z 127.0.0.1 "$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
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

# Check if GitLab is already installed
if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE"; then
    print_warning "GitLab is already installed. Upgrading..."
    helm upgrade "$HELM_RELEASE" gitlab/gitlab \
        --namespace "$NAMESPACE" \
        --set global.hosts.domain=localhost \
        --set global.hosts.externalIP=127.0.0.1 \
        --set certmanager.install=false \
        --set global.ingress.tls.enabled=false \
        --set gitlab-runner.install=true
else
    print_status "Creating namespace and installing GitLab..."
    kubectl create namespace "$NAMESPACE" 2>/dev/null || true
    
    helm install "$HELM_RELEASE" gitlab/gitlab \
        --namespace "$NAMESPACE" \
        --set global.hosts.domain=localhost \
        --set global.hosts.externalIP=127.0.0.1 \
        --set certmanager.install=false \
        --set global.ingress.tls.enabled=false \
        --set gitlab-runner.install=true
fi

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

print_section "Step 5: Dynamic Service Discovery"
print_status "Discovering GitLab service access information..."

# Get service URLs
SERVICE_URLS=$(get_service_urls)

if [ -n "$SERVICE_URLS" ]; then
    print_success "Service URLs discovered:"
    echo "$SERVICE_URLS"
    
    # Extract ports
    PORTS=$(extract_ports "$SERVICE_URLS")
    HTTP_PORT=$(echo "$PORTS" | cut -d',' -f1)
    HTTPS_PORT=$(echo "$PORTS" | cut -d',' -f2)
    
    # Test connectivity
    print_status "Testing port connectivity..."
    
    if [ -n "$HTTP_PORT" ] && test_port "$HTTP_PORT"; then
        print_success "HTTP port $HTTP_PORT is accessible"
        HTTP_ACCESSIBLE=true
    else
        HTTP_ACCESSIBLE=false
        [ -n "$HTTP_PORT" ] && print_warning "HTTP port $HTTP_PORT is not accessible"
    fi
    
    if [ -n "$HTTPS_PORT" ] && test_port "$HTTPS_PORT"; then
        print_success "HTTPS port $HTTPS_PORT is accessible"
        HTTPS_ACCESSIBLE=true
    else
        HTTPS_ACCESSIBLE=false
        [ -n "$HTTPS_PORT" ] && print_warning "HTTPS port $HTTPS_PORT is not accessible"
    fi
    
else
    print_warning "Could not auto-discover service URLs"
    print_status "You'll need to start the service tunnel manually"
    HTTP_ACCESSIBLE=false
    HTTPS_ACCESSIBLE=false
fi

print_section "Step 6: Get Login Credentials"
print_status "Retrieving root password..."

# Wait a moment for the secret to be created
sleep 2

ROOT_PASSWORD=""
for i in {1..5}; do
    ROOT_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n "$NAMESPACE" -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "")
    if [ -n "$ROOT_PASSWORD" ]; then
        break
    fi
    print_status "Waiting for root password secret... (attempt $i/5)"
    sleep 5
done

if [ -n "$ROOT_PASSWORD" ]; then
    print_success "Root password retrieved"
else
    print_error "Could not retrieve root password. You may need to wait longer and check manually."
fi

echo ""
echo "🎉 GitLab Installation Complete!"
echo ""

print_section "Access Information"

if [ "$HTTPS_ACCESSIBLE" = true ]; then
    echo "🌐 GitLab URL: https://$HOSTNAME:$HTTPS_PORT"
    print_success "GitLab is ready to use!"
    
    echo ""
    echo "🔑 Login Credentials:"
    echo "   Username: root"
    [ -n "$ROOT_PASSWORD" ] && echo "   Password: $ROOT_PASSWORD"
    
    echo ""
    echo "🧪 Test connectivity:"
    echo "   curl -k -I https://$HOSTNAME:$HTTPS_PORT"
    
elif [ "$HTTP_ACCESSIBLE" = true ]; then
    echo "🌐 GitLab URL: http://$HOSTNAME:$HTTP_PORT"
    print_warning "Only HTTP is accessible (will redirect to HTTPS)"
    
    echo ""
    echo "🔑 Login Credentials:"
    echo "   Username: root"
    [ -n "$ROOT_PASSWORD" ] && echo "   Password: $ROOT_PASSWORD"
    
else
    print_warning "Service ports not automatically accessible"
    echo ""
    echo "📋 Manual Setup Required:"
    echo "1. Run this command in a separate terminal:"
    echo "   minikube service gitlab-nginx-ingress-controller -n $NAMESPACE --url"
    echo ""
    echo "2. Note the HTTPS port from the output"
    echo ""
    echo "3. Access GitLab: https://$HOSTNAME:[HTTPS_PORT]"
    echo ""
    echo "🔑 Login Credentials:"
    echo "   Username: root"
    [ -n "$ROOT_PASSWORD" ] && echo "   Password: $ROOT_PASSWORD"
fi

echo ""
echo "⚠️  Important Notes:"
echo "   - Your browser will show a security warning (click Advanced → Proceed)"
echo "   - If using manual setup, keep the minikube service terminal open"
echo "   - Service ports may change when restarting minikube"

echo ""
echo "🔧 Troubleshooting Commands:"
echo "   - Check pods: kubectl get pods -n $NAMESPACE"
echo "   - Check ingress: kubectl get ingress -n $NAMESPACE" 
echo "   - View webservice logs: kubectl logs -n $NAMESPACE -l app=webservice"
echo "   - Get service URLs: minikube service gitlab-nginx-ingress-controller -n $NAMESPACE --url"

# If accessible, offer to open browser
if [ "$HTTPS_ACCESSIBLE" = true ] && command -v open >/dev/null 2>&1; then
    echo ""
    read -p "🌐 Open GitLab in your default browser? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Opening https://$HOSTNAME:$HTTPS_PORT in browser..."
        open "https://$HOSTNAME:$HTTPS_PORT" 2>/dev/null || print_warning "Could not open browser automatically"
    fi
fi
