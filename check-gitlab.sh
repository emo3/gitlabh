#!/bin/bash

set -e

echo "=== Check GitLab Local Installation Script (Minikube + Helm) ==="

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Function to install missing dependencies
install_missing () {
  echo "Installing missing dependencies: $1..."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux-based OS
    if command_exists dnf; then
      # Fedora/RHEL-based systems
      sudo dnf install -y $1
    elif command_exists apt-get; then
      # Debian/Ubuntu-based systems
      sudo apt-get update
      sudo apt-get install -y $1
    else
      echo "❌ Unsupported Linux package manager. Please install $1 manually."
      exit 1
    fi

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
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
      # macOS: Start Docker Desktop automatically
      open -a Docker
      # Wait for Docker to start (increased wait time for macOS)
      echo "Waiting for Docker to start on macOS (60 seconds)..."
      sleep 60  # Give it 60 seconds to start up
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      # Linux: Try to start Docker using systemd
      sudo systemctl start docker
      # Wait for Docker to start
      echo "Waiting for Docker to start on Linux..."
      sleep 10  # Give it 10 seconds to start up
    fi

    # Check if Docker started successfully
    if ! docker info >/dev/null 2>&1; then
      echo "❌ Docker failed to start. Please ensure Docker is installed and properly configured."
      exit 1
    fi
  fi

  echo "✅ Docker is running."
}

# Function to check if Docker socket exists and is accessible
check_docker_socket () {
  if [ ! -S /var/run/docker.sock ] && [ ! -S /Users/emo3/.docker/run/docker.sock ]; then
    echo "❌ Docker socket not found. Docker might not be properly initialized."
    exit 1
  fi
}

# Function to start Minikube if not already running
start_minikube_if_not_running () {
  if ! minikube status >/dev/null 2>&1; then
    echo "Minikube is not running. Starting Minikube..."
    minikube start --memory=8192 --cpus=4 --driver=docker
  else
    echo "✅ Minikube is already running. Skipping Minikube start."
  fi
}

echo ""
echo "--- Step 1: Verify Prerequisites ---"
# Check for Docker
if ! command_exists docker; then
  echo "❌ Docker is not installed. Attempting to install Docker..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_missing docker
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    install_missing docker
  fi
  if ! command_exists docker; then
    echo "❌ Docker installation failed. Please install Docker manually."
    exit 1
  fi
else
  # Check if Docker is running and start it if necessary
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
# Start Minikube only if it is not already running
start_minikube_if_not_running

echo ""
echo "--- Step 3: Add Helm Repo & Namespace ---"
# Check if the GitLab Helm repo is already added
if helm repo list | grep -q "gitlab"; then
  echo "✅ GitLab Helm repo already exists. Skipping adding repo."
else
  helm repo add gitlab https://charts.gitlab.io/
  helm repo update
  echo "✅ GitLab Helm repo added and updated."
fi

# Check if the GitLab namespace exists
if kubectl get namespace gitlab >/dev/null 2>&1; then
  echo "✅ GitLab namespace already exists. Skipping namespace creation."
else
  kubectl create namespace gitlab
  echo "✅ GitLab namespace created."
fi
