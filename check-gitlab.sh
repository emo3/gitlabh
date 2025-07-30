#!/bin/bash

set -e

echo "=== Check GitLab Local Installation Prerequisites (Minikube + Helm) ==="

# Configuration
NAMESPACE="gitlab"
VALUES_FILE="minimal-values.yaml"

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install missing dependencies
install_missing() {
    print_status "Installing missing dependencies: $1..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists dnf; then
            sudo dnf install -y $1
        elif command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y $1
        elif command_exists yum; then
            sudo yum install -y $1
        else
            print_error "Unsupported Linux package manager. Please install $1 manually."
            return 1
        fi

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install $1
        else
            print_error "Homebrew not found. Please install Homebrew first or install $1 manually."
            print_status "Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi

    else
        print_error "Unsupported OS: $OSTYPE. Please install $1 manually."
        return 1
    fi
}

# Function to check if Docker is running and start it if not
start_docker_if_not_running() {
    print_status "Checking if Docker is running..."

    if ! docker info >/dev/null 2>&1; then
        print_warning "Docker is not running. Starting Docker..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [ -d "/Applications/Docker.app" ]; then
                open -a Docker
                print_status "Waiting for Docker to start on macOS (60 seconds)..."
                sleep 60
            else
                print_error "Docker Desktop not found in /Applications/. Please install Docker Desktop."
                return 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command_exists systemctl; then
                sudo systemctl start docker
                print_status "Waiting for Docker to start on Linux..."
                sleep 10
            else
                print_error "systemctl not found. Please start Docker manually."
                return 1
            fi
        fi

        # Verify Docker started
        local attempts=0
        while [ $attempts -lt 12 ]; do  # 60 seconds total
            if docker info >/dev/null 2>&1; then
                break
            fi
            sleep 5
            attempts=$((attempts + 1))
        done

        if ! docker info >/dev/null 2>&1; then
            print_error "Docker failed to start. Please ensure Docker is installed and properly configured."
            return 1
        fi
    fi

    print_success "Docker is running"
}

# Function to check for Docker socket
check_docker_socket() {
    if [ ! -S /var/run/docker.sock ] && [ ! -S "$HOME/.docker/run/docker.sock" ] && [ ! -S "/Users/$USER/.docker/run/docker.sock" ]; then
        print_error "Docker socket not found. Docker might not be properly initialized."
        print_status "Common Docker socket locations checked:"
        print_status "  - /var/run/docker.sock"
        print_status "  - $HOME/.docker/run/docker.sock"
        print_status "  - /Users/$USER/.docker/run/docker.sock"
        return 1
    fi
    print_success "Docker socket found"
}

# Function to start Minikube if not running
start_minikube_if_not_running() {
    print_status "Checking Minikube status..."
    
    if ! minikube status >/dev/null 2>&1; then
        print_warning "Minikube is not running. Starting Minikube..."
        minikube start --memory=8192 --cpus=4 --driver=docker
    else
        local status=$(minikube status --format '{{.Host}}' 2>/dev/null || echo "Unknown")
        if [[ "$status" != "Running" ]]; then
            print_warning "Minikube status: $status. Starting Minikube..."
            minikube start --memory=8192 --cpus=4 --driver=docker
        else
            print_success "Minikube is already running"
        fi
    fi
}

# Function to create configuration file if missing
create_config_file() {
    if [ ! -f "$VALUES_FILE" ]; then
        print_warning "Configuration file '$VALUES_FILE' not found. Creating it..."
        
        cat > "$VALUES_FILE" << 'EOF'
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
        print_success "Created '$VALUES_FILE' with default configuration"
        print_status "You may need to update the externalIP (192.168.49.2) to match your minikube IP"
    else
        print_success "Configuration file '$VALUES_FILE' found"
    fi
}

echo ""
echo "--- Step 1: Verify Prerequisites ---"

# Check for Docker
if ! command_exists docker; then
    print_error "Docker is not installed. Attempting to install Docker..."
    if install_missing docker; then
        print_success "Docker installed successfully"
    else
        print_error "Docker installation failed. Please install Docker manually."
        exit 1
    fi
else
    if start_docker_if_not_running && check_docker_socket; then
        print_success "Docker is ready"
    else
        print_error "Docker setup failed"
        exit 1
    fi
fi

# Check for Minikube
if ! command_exists minikube; then
    print_error "Minikube is not installed. Attempting to install Minikube..."
    if install_missing minikube; then
        print_success "Minikube installed successfully"
    else
        print_error "Minikube installation failed. Please install Minikube manually."
        exit 1
    fi
else
    print_success "Minikube is installed"
fi

# Check for kubectl
if ! command_exists kubectl; then
    print_error "kubectl is not installed. Attempting to install kubectl..."
    if install_missing kubectl; then
        print_success "kubectl installed successfully"
    else
        print_error "kubectl installation failed. Please install kubectl manually."
        exit 1
    fi
else
    print_success "kubectl is installed"
fi

# Check for Helm
if ! command_exists helm; then
    print_error "Helm is not installed. Attempting to install Helm..."
    if install_missing helm; then
        print_success "Helm installed successfully"
    else
        print_error "Helm installation failed. Please install Helm manually."
        exit 1
    fi
else
    print_success "Helm is installed"
fi

# Note: Removed Caddy check as it's not needed for the working setup

print_success "All prerequisites are met"

echo ""
echo "--- Step 2: Start Minikube ---"
start_minikube_if_not_running

print_status "Setting kubectl context to Minikube..."
kubectl config use-context minikube

print_status "Verifying connection to Kubernetes API server..."
sleep 5  # Give context time to settle

# Verify kubectl connection
if ! kubectl get nodes >/dev/null 2>&1; then
    print_error "Unable to connect to Kubernetes API server. Please verify Minikube is configured correctly:"
    echo "   - Try: minikube status"
    echo "   - Check kubeconfig: kubectl config view"
    echo "   - Try: minikube delete && minikube start"
    exit 1
else
    print_success "Connected to Kubernetes API server"
fi

# Get and display minikube IP
MINIKUBE_IP=$(minikube ip)
print_success "Minikube IP: $MINIKUBE_IP"

echo ""
echo "--- Step 3: Configure Kubernetes ---"

print_status "Enabling Minikube ingress addon..."
minikube addons enable ingress >/dev/null 2>&1
print_success "Ingress addon enabled"

echo ""
echo "--- Step 4: Setup Helm Repository ---"

if helm repo list 2>/dev/null | grep -q "gitlab"; then
    print_success "GitLab Helm repo already exists"
else
    helm repo add gitlab https://charts.gitlab.io/ >/dev/null 2>&1
    print_success "GitLab Helm repo added"
fi

helm repo update >/dev/null 2>&1
print_success "Helm repositories updated"

echo ""
echo "--- Step 5: Setup Namespace ---"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    print_success "GitLab namespace already exists"
else
    kubectl create namespace "$NAMESPACE"
    print_success "GitLab namespace created"
fi

echo ""
echo "--- Step 6: Configuration File ---"
create_config_file

echo ""
echo "🎉 Environment Check Complete!"
echo ""
echo "📋 Summary:"
echo "   ✅ Docker: Running"
echo "   ✅ Minikube: Running (IP: $MINIKUBE_IP)"
echo "   ✅ kubectl: Connected to cluster"
echo "   ✅ Helm: Ready with GitLab repo"
echo "   ✅ Namespace: $NAMESPACE created"
echo "   ✅ Configuration: $VALUES_FILE ready"
echo ""
echo "🚀 Next Steps:"
echo "   1. Run: ./install-gitlab.sh"
echo "   2. Or manually run:"
echo "      helm upgrade --install gitlab gitlab/gitlab -n $NAMESPACE -f $VALUES_FILE --timeout 10m"
echo ""
echo "💡 Troubleshooting Commands:"
echo "   - Check cluster: kubectl get nodes"
echo "   - Check minikube: minikube status"
echo "   - Check addons: minikube addons list"
echo "   - Reset if needed: minikube delete && minikube start"
