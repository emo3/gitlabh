#!/bin/bash

# This script verifies the necessary prerequisites (Docker, Minikube, Helm, and kubectl)
# for deploying GitLab using Helm charts. If not found, it provides
# installation instructions or attempts to install them.

echo "--- Verifying GitLab Helm Chart Prerequisites ---"

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# --- Check for Docker ---
echo ""
echo "Checking for Docker..."
if command_exists docker; then
  echo "Docker found: $(docker version --format '{{.Client.Version}}')"
else
  echo "Docker not found. Docker Desktop (or another container runtime like Podman, Colima, or Rancher Desktop) is required for Minikube."
  echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
  exit 1
fi

# --- Check for Minikube ---
echo ""
echo "Checking for Minikube..."
if command_exists minikube; then
  echo "Minikube found: $(minikube version --short)"
else
  echo "Minikube not found. Attempting to install..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux installation
    echo "Attempting to install Minikube for Linux..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    if command_exists minikube; then
      echo "Minikube installed successfully: $(minikube version --short)"
    else
      echo "Failed to install Minikube automatically. Please install it manually."
      echo "  For Linux: https://minikube.sigs.k8s.io/docs/start/"
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS installation (using Homebrew)
    echo "Attempting to install Minikube for macOS using Homebrew..."
    if command_exists brew; then
      brew install minikube
      if command_exists minikube; then
        echo "Minikube installed successfully: $(minikube version --short)"
      else
        echo "Failed to install Minikube automatically. Please install Homebrew and then run 'brew install minikube'."
        echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
      fi
    else
      echo "Homebrew not found. Please install Homebrew first, then run 'brew install minikube'."
      echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
  else
    echo "Unsupported OS for automatic Minikube installation. Please install Minikube manually."
    echo "  Refer to: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
  fi
fi

# --- Check for kubectl ---
echo ""
echo "Checking for kubectl..."
if command_exists kubectl; then
  echo "kubectl found: $(kubectl version --client)"
else
  echo "kubectl not found. Attempting to install..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux installation (Ubuntu/Debian example)
    echo "Attempting to install kubectl for Linux..."
    sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
    if command_exists kubectl; then
      echo "kubectl installed successfully: $(kubectl version --client)"
    else
      echo "Failed to install kubectl automatically. Please install it manually."
      echo "  For Linux: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
      echo "  For macOS (using Homebrew): brew install kubectl"
      echo "  For Windows (using Chocolatey): choco install kubernetes-cli"
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS installation (using Homebrew)
    echo "Attempting to install kubectl for macOS using Homebrew..."
    if command_exists brew; then
      brew install kubectl
      if command_exists kubectl; then
        echo "kubectl installed successfully: $(kubectl version --client)"
      else
        echo "Failed to install kubectl automatically. Please install Homebrew and then run 'brew install kubectl'."
        echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
      fi
    else
      echo "Homebrew not found. Please install Homebrew first, then run 'brew install kubectl'."
      echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
  else
    echo "Unsupported OS for automatic kubectl installation. Please install kubectl manually."
    echo "  Refer to: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
fi

# --- Check for Helm ---
echo ""
echo "Checking for Helm..."
if command_exists helm; then
  echo "Helm found: $(helm version --short)"
else
  echo "Helm not found. Attempting to install..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux installation (generic via curl)
    echo "Attempting to install Helm for Linux..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    if command_exists helm; then
      echo "Helm installed successfully: $(helm version --short)"
    else
      echo "Failed to install Helm automatically. Please install it manually."
      echo "  For Linux: https://helm.sh/docs/intro/install/#from-script"
      echo "  For macOS (using Homebrew): brew install helm"
      echo "  For Windows (using Chocolatey): choco install kubernetes-helm"
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS installation (using Homebrew)
    echo "Attempting to install Helm for macOS using Homebrew..."
    if command_exists brew; then
      brew install helm
      if command_exists helm; then
        echo "Helm installed successfully: $(helm version --short)"
      else
        echo "Failed to install Helm automatically. Please install Homebrew and then run 'brew install helm'."
        echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
      fi
    else
      echo "Homebrew not found. Please install Homebrew first, then run 'brew install helm'."
      echo "  Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
  else
    echo "Unsupported OS for automatic Helm installation. Please install Helm manually."
    echo "  Refer to: https://helm.sh/docs/intro/install/"
    exit 1
  fi
fi

echo ""
echo "--- All prerequisites met! ---"
echo "Your environment is ready to deploy GitLab using Helm charts."
echo ""
echo "Next steps:"
echo "1. Start your Minikube cluster (if not already running):"
echo "   minikube start --memory 8192 --cpus 4 --driver=docker" # Removed --disk flag
echo ""
echo "2. Add the GitLab Helm repository:"
echo "   helm repo add gitlab https://charts.gitlab.io/"
echo "   helm repo update"
echo ""
echo "3. Install GitLab (refer to official documentation for detailed configuration):"
echo "   helm install gitlab gitlab/gitlab -f your-values.yaml --version <chart-version> --namespace gitlab --create-namespace"
echo "   (Replace 'your-values.yaml' with your custom configuration file and '<chart-version>' with the desired chart version)"
