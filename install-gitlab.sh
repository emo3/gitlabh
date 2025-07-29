#!/bin/bash

set -e

echo "=== GitLab Local Installation Script (Minikube + Helm + Caddy) ==="

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
./wait.sh
echo "All GitLab pods are ready."

echo ""
echo "--- Step 6: Configure Host Mapping ---"
if ! grep -q "gitlab.example.com" /etc/hosts; then
  echo "127.0.0.1 gitlab.example.com" | sudo tee -a /etc/hosts
fi

echo ""
echo "✅ GitLab is now accessible at: https://gitlab.example.com"
echo "➡️ Default login: root / YourInsecureTestPasswordHere (from your YAML file)"
echo "⚠️ You may see a browser security warning due to the self-signed certificate."
