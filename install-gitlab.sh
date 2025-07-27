#!/bin/bash

set -e

echo "=== GitLab Local Installation Script (Minikube + Helm + Caddy) ==="

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

echo ""
echo "--- Step 1: Verify Prerequisites ---"
# Check for Docker
if ! command_exists docker; then
  echo "❌ Docker is not installed. Please install Docker."
  exit 1
fi

# Check for Minikube
if ! command_exists minikube; then
  echo "❌ Minikube is not installed. Please install Minikube."
  exit 1
fi

# Check for kubectl
if ! command_exists kubectl; then
  echo "❌ kubectl is not installed. Please install kubectl."
  exit 1
fi

# Check for Helm
if ! command_exists helm; then
  echo "❌ Helm is not installed. Please install Helm."
  exit 1
fi

# Check for Caddy
if ! command_exists caddy; then
  echo "❌ Caddy is not installed. Please install Caddy."
  exit 1
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
sudo systemctl restart caddy
sleep 2

echo ""
echo "✅ GitLab is now accessible at: https://gitlab.example.com"
echo "➡️ Default login: root / YourInsecureTestPasswordHere (from your YAML file)"
echo "⚠️ You may see a browser security warning due to the self-signed
