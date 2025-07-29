#!/bin/bash

# Get the Minikube IP
MINIKUBE_IP=$(minikube ip)

# GitLab service port inside the cluster
GITLAB_PORT=8080

# Create the Caddyfile
cat <<EOF > Caddyfile
gitlab.example.com:443 {
    reverse_proxy http://localhost:8080 {
        header_up Host gitlab.example.com
    }
    tls internal
}
EOF

echo "Caddyfile has been created at: Caddyfile"

# Run Caddy in foreground with internal TLS, skip cert trust install to avoid sudo prompt
echo "Starting Caddy in foreground (no sudo)..."
CADDY_SKIP_INSTALL_TRUST=1 caddy run --config Caddyfile
