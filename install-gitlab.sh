#!/bin/bash

set -e

echo "=== GitLab Local Installation Script (Minikube + Helm + Caddy) ==="

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
minikube start --memory=8192 --cpus=4 --driver=docker

echo ""
echo "--- Step 3: Add Helm Repo & Namespace ---"
helm repo add gitlab https://charts.gitlab.io/
helm repo update
kubectl create namespace gitlab || echo "Namespace 'gitlab' already exists."

echo ""
echo "--- Step 4: Install GitLab Helm Chart ---"
if [ ! -f gitlab-local-values.yaml ]; then
  echo "❌ Missing 'gitlab-local-values.yaml' in current directory."
  exit 1
fi

# Check if required values are set in gitlab-local-values.yaml
if ! grep -q "externalUrl:" gitlab-local-values.yaml; then
  echo "❌ 'externalUrl' is not set in gitlab-local-values.yaml. Please add the URL."
  exit 1
fi

# Install or upgrade the GitLab chart
echo "Installing or upgrading GitLab..."
if ! helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f gitlab-local-values.yaml \
  --create-namespace; then
  echo "❌ Failed to install or upgrade GitLab. Check the logs for more details."
  exit 1
fi

echo ""
echo "--- Step 5: Wait for GitLab Pods to be Ready ---"
echo "Waiting for all GitLab pods to be ready (timeout: 600 seconds)..."
if ! kubectl wait --namespace gitlab \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/part-of=gitlab \
  --timeout=600s; then
  echo "❌ Timed out waiting for GitLab pods to be ready after 600 seconds."
  echo "Check pod status with: kubectl get pods -n gitlab"
  exit 1
fi
echo "All GitLab pods are ready."

echo ""
echo "--- Step 6: Configure Host Mapping ---"
if ! grep -q "gitlab.example.com" /etc/hosts; then
  echo "127.0.0.1 gitlab.example.com" | sudo tee -a /etc/hosts
fi

echo ""
echo "--- Step 7: Configure Caddy Reverse Proxy ---"
MINIKUBE_IP=$(minikube ip)

# Dynamically retrieve the GitLab service port
echo "Retrieving GitLab service port..."
GITLAB_PORT=$(kubectl get service -n gitlab -l app.kubernetes.io/name=webservice -o jsonpath='{.items[0].spec.ports[?(@.name=="http")].nodePort}')

if [ -z "$GITLAB_PORT" ]; then
  echo "❌ Failed to retrieve GitLab service port. Ensure GitLab is properly deployed."
  exit 1
fi
echo "GitLab service port: $GITLAB_PORT"

cat <<EOF | sudo tee /etc/caddy/Caddyfile
gitlab.example.com:443 {
    reverse_proxy https://$MINIKUBE_IP:$GITLAB_PORT {
        header_up Host gitlab.example.com
        transport http {
            tls_insecure_skip_verify
        }
    }
    tls internal
}
EOF

echo ""
echo "--- Step 8: Start Caddy ---"
sudo systemctl restart caddy || { echo "❌ Failed to restart Caddy. Check system logs for more details."; exit 1; }
sleep 2

echo ""
echo "✅ GitLab is now accessible at: https://gitlab.example.com"
echo "➡️ Default login: root / YourInsecureTestPasswordHere (from your YAML file)"
echo "⚠️ Note: The connection is secured with a self-signed certificate, so your browser may show a security warning. You can safely proceed by adding an exception."
