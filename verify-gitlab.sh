#!/bin/bash

set -e

HOST_ENTRY="127.0.0.1 gitlab.localhost"
HOSTS_FILE="/etc/hosts"
HOSTNAME="gitlab.localhost"
NAMESPACE="gitlab"
TIMEOUT=10
ALLOW_SELF_SIGNED=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to run command with timeout
run_with_timeout() {
    local timeout=$1
    shift
    timeout "$timeout" "$@" 2>/dev/null || return 1
}

echo "🔧 Starting GitLab connectivity diagnostics..."

# Check if minikube is running
echo ""
echo "🔍 Step 1: Checking Minikube status..."
if minikube status >/dev/null 2>&1; then
    MINIKUBE_IP=$(minikube ip)
    print_success "Minikube is running (IP: $MINIKUBE_IP)"
else
    print_error "Minikube is not running. Please start it first with:"
    echo "  minikube start --memory=8192 --cpus=4 --driver=docker"
    exit 1
fi

# Check /etc/hosts
echo ""
echo "🔍 Step 2: Checking /etc/hosts entry..."
if grep -q "$HOST_ENTRY" "$HOSTS_FILE"; then
    print_success "Found /etc/hosts entry: $HOST_ENTRY"
else
    print_error "/etc/hosts is missing required entry: $HOST_ENTRY"
    echo "Add it manually with:"
    echo "  echo \"$HOST_ENTRY\" | sudo tee -a $HOSTS_FILE"
    exit 1
fi

# Check GitLab pods
echo ""
echo "🔍 Step 3: Checking GitLab pods in namespace '$NAMESPACE'..."
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    print_success "GitLab namespace exists"
    
    # Count running pods
    running_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
        grep -v "gitlab-runner" | \
        grep -E "(Running|Completed)" | \
        wc -l | tr -d ' ')
    
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
        grep -v "gitlab-runner" | \
        wc -l | tr -d ' ')
    
    if [ "$total_pods" -gt 0 ]; then
        if [ "$running_pods" -eq "$total_pods" ]; then
            print_success "All GitLab pods are ready ($running_pods/$total_pods)"
        else
            print_warning "Some pods not ready ($running_pods/$total_pods)"
            echo "Pod status:"
            kubectl get pods -n "$NAMESPACE"
        fi
    else
        print_error "No GitLab pods found. Is GitLab installed?"
        exit 1
    fi
else
    print_error "GitLab namespace '$NAMESPACE' does not exist"
    exit 1
fi

# Check ingress
echo ""
echo "🔍 Step 4: Checking GitLab ingress..."
if kubectl get ingress -n "$NAMESPACE" >/dev/null 2>&1; then
    print_success "GitLab ingress exists"
    kubectl get ingress -n "$NAMESPACE"
else
    print_warning "No ingress found in namespace '$NAMESPACE'"
fi

# Resolve hostname using ping (respects /etc/hosts)
echo ""
echo "🔍 Step 5: Resolving $HOSTNAME to IP..."
RESOLVED_IP=$(ping -c 1 "$HOSTNAME" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1 || echo "")
if [ -z "$RESOLVED_IP" ]; then
    print_error "Could not resolve $HOSTNAME. Check /etc/hosts."
    exit 1
fi
print_success "Resolved $HOSTNAME to $RESOLVED_IP"

# Ping test
echo ""
echo "🔍 Step 6: Pinging $RESOLVED_IP..."
if ping -c 1 -W 1 "$RESOLVED_IP" > /dev/null 2>&1; then
    print_success "Ping successful"
else
    print_warning "Ping failed (may be expected if ICMP blocked)"
fi

# Check Docker if available
echo ""
echo "🔍 Step 7: Checking Docker status..."
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        print_success "Docker daemon is running"
        
        # Show running containers related to minikube
        print_status "Minikube-related containers:"
        docker ps --filter name=minikube --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "None found"
    else
        print_error "Docker daemon is NOT running"
    fi
else
    print_warning "Docker is not installed or not in PATH"
fi

echo ""
echo "🏁 Diagnostics complete."
echo ""
echo "📋 Summary:"
echo "  - Minikube: Running (IP: $MINIKUBE_IP)"
echo "  - GitLab namespace: Exists"
echo "  - GitLab pods: $running_pods/$total_pods ready"
echo "  - Hostname resolution: Working ($HOSTNAME → $RESOLVED_IP)"

echo ""
echo "🔑 Get root password:"
kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode && echo

echo ""
echo "🧪 Test connectivity:"
curl -k -I http://$HOSTNAME:8080
