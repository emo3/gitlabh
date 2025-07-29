#!/bin/bash

set -e

echo "=== Check GitLab Local Installation Script (Minikube + Helm + Caddy) ==="

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Function to install missing dependencies
install_missing () {
  echo "Installing missing dependencies: $1..."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command_exists dnf; then
      sudo dnf install -y $1
    elif command_exists apt-get; then
      sudo apt-get update
      sudo apt-get install -y $1
    else
      echo "❌ Unsupported Linux package manager. Please install $1 manually."
      exit 1
    fi

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install $1

  else
    echo "❌ Unsupported OS: $OSTYPE. Please install $1 manually."
    exit 1
  fi
}

# Function to check if Docker is running and start it if not
start_docker_if_not_running () {
  echo "Checking if Docker is running..."

  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Starting Docker..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
      open -a Docker
      echo "Waiting for Docker to start on macOS (60 seconds)..."
      sleep 60
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo systemctl start docker
      echo "Waiting for Docker to start on Linux..."
      sleep 10
    fi

    if ! docker info >/dev/null 2>&1; then
      echo "❌ Docker failed to start. Please ensure Docker is installed and properly configured."
      exit 1
    fi
  fi

  echo "✅ Docker is running."
}

# Function to check for Docker socket
check_docker_socket () {
  if [ ! -S /var/run/docker.sock ] && [ ! -S /Users/emo3/.docker/run/docker.sock ]; then
    echo "❌ Docker socket not found. Docker might not be properly initialized."
    exit 1
  fi
}

# Function to start Minikube if not running
start_minikube_if_not_running () {
  echo "Checking Minikube status..."
  if ! minikube status >/dev/null 2>&1 || [[ "$(minikube status --format '{{.Host}}')" != "Running" ]]; then
    echo "Minikube is not running. Starting Minikube..."
    minikube start --memory=8192 --cpus=4 --driver=docker
  else
    echo "✅ Minikube is already running."
  fi
}

echo ""
echo "--- Step 1: Verify Prerequisites ---"

# Check for Docker
if ! command_exists docker; then
  echo "❌ Docker is not installed. Attempting to install Docker..."
  install_missing docker
  if ! command_exists docker; then
    echo "❌ Docker installation failed. Please install Docker manually."
    exit 1
  fi
else
  start_docker_if_not_running
  check_docker_socket
fi

# Check for Minikube
if ! command_exists minikube; then
  echo "❌ Minikube is not installed. Attempting to install Minikube..."
  install_missing minikube
  if ! command_exists minikube; then
    echo "❌ Minikube installation failed. Please install Minikube manually."
    exit 1
  fi
fi

# Check for kubectl
if ! command_exists kubectl; then
  echo "❌ kubectl is not installed. Attempting to install kubectl..."
  install_missing kubectl
  if ! command_exists kubectl; then
    echo "❌ kubectl installation failed. Please install kubectl manually."
    exit 1
  fi
fi

# Check for Helm
if ! command_exists helm; then
  echo "❌ Helm is not installed. Attempting to install Helm..."
  install_missing helm
  if ! command_exists helm; then
    echo "❌ Helm installation failed. Please install Helm manually."
    exit 1
  fi
fi

# Check for Caddy
if ! command_exists caddy; then
  echo "❌ Caddy is not installed. Attempting to install Caddy..."
  install_missing caddy
  if ! command_exists caddy; then
    echo "❌ Caddy installation failed. Please install Caddy manually."
    exit 1
  fi
fi

echo "✅ All prerequisites are met."

echo ""
echo "--- Step 2: Start Minikube ---"
start_minikube_if_not_running

echo "📌 Setting kubectl context to Minikube..."
kubectl config use-context minikube

echo "🔍 Verifying connection to Kubernetes API server..."
sleep 5  # Give context time to settle

# Ensure we're using Minikube's kubeconfig
export KUBECONFIG=$(minikube kubeconfig)

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "❌ Unable to connect to Kubernetes API server. Please verify Minikube is configured correctly:"
  echo "   - Try: minikube status"
  echo "   - Check kubeconfig: kubectl config view"
  exit 1
else
  echo "✅ Connected to Kubernetes API server."
fi

echo "⚙️ Enabling Minikube ingress addon..."
minikube addons enable ingress

echo ""
echo "--- Step 3: Add Helm Repo & Namespace ---"

if helm repo list | grep -q "gitlab"; then
  echo "✅ GitLab Helm repo already exists. Skipping adding repo."
else
  helm repo add gitlab https://charts.gitlab.io/
  helm repo update
  echo "✅ GitLab Helm repo added and updated."
fi

if kubectl get namespace gitlab >/dev/null 2>&1; then
  echo "✅ GitLab namespace already exists. Skipping namespace creation."
else
  kubectl create namespace gitlab
  echo "✅ GitLab namespace created."
fi
