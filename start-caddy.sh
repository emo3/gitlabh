#!/bin/bash

# Set the Minikube IP
MINIKUBE_IP=$(minikube ip)

# Dynamically retrieve the GitLab service port
echo "Retrieving GitLab service port..."
GITLAB_PORT=$(kubectl get service -n gitlab -l app.kubernetes.io/name=webservice -o jsonpath='{.items[0].spec.ports[?(@.name=="http")].nodePort}')

if [ -z "$GITLAB_PORT" ]; then
  echo "❌ Failed to retrieve GitLab service port. Ensure GitLab is properly deployed."
  exit 1
fi

echo "GitLab service port: $GITLAB_PORT"

# Define a local directory for the Caddyfile
CADDYFILE_DIR="$HOME/caddy-config"
mkdir -p "$CADDYFILE_DIR"

# Create the Caddyfile in the local directory
cat <<EOF > "$CADDYFILE_DIR/Caddyfile"
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

echo "Caddyfile has been created at $CADDYFILE_DIR/Caddyfile"
