#!/bin/bash
set -e

echo "=== GitLab Cleanup Script ==="

# Define the namespace and release name
NAMESPACE="gitlab"
RELEASE_NAME="gitlab"
HOSTS_ENTRY="gitlab.localhost"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely remove hosts entry
remove_hosts_entry() {
    if grep -q "$HOSTS_ENTRY" /etc/hosts 2>/dev/null; then
        echo "Removing $HOSTS_ENTRY from /etc/hosts..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sudo sed -i '' "/$HOSTS_ENTRY/d" /etc/hosts
        else
            # Linux
            sudo sed -i "/$HOSTS_ENTRY/d" /etc/hosts
        fi
        echo "✅ Removed $HOSTS_ENTRY from /etc/hosts"
    else
        echo "ℹ️  No $HOSTS_ENTRY entry found in /etc/hosts"
    fi
}

# Function to kill minikube service processes
kill_service_tunnels() {
    echo "Checking for active minikube service tunnels..."
    
    # Find and kill minikube service processes
    if pgrep -f "minikube service.*gitlab" >/dev/null 2>&1; then
        echo "Killing active minikube service tunnels..."
        pkill -f "minikube service.*gitlab" || true
        echo "✅ Killed minikube service tunnels"
    else
        echo "ℹ️  No active minikube service tunnels found"
    fi
}

# Check prerequisites
if ! command_exists kubectl; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command_exists helm; then
    echo "❌ helm not found. Please install helm first."
    exit 1
fi

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
    echo "⚠️  Minikube is not running. Some cleanup steps may be skipped."
fi

# Kill any active service tunnels first
kill_service_tunnels

# Uninstall Helm release first (cleaner than just deleting namespace)
echo "Checking for GitLab Helm release..."
if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME" 2>/dev/null; then
    echo "Uninstalling GitLab Helm release '$RELEASE_NAME'..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --timeout 10m
    echo "✅ GitLab Helm release uninstalled"
else
    echo "ℹ️  No GitLab Helm release found in namespace '$NAMESPACE'"
fi

# Wait a moment for resources to be cleaned up
echo "Waiting for resources to be cleaned up..."
sleep 5

# Check if the namespace exists and delete it
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Deleting GitLab namespace '$NAMESPACE' and any remaining resources..."
    kubectl delete namespace "$NAMESPACE" --timeout=300s
    
    # Wait for namespace deletion to complete
    echo "Waiting for namespace deletion to complete..."
    while kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; do
        echo "  Still waiting for namespace deletion..."
        sleep 5
    done
    echo "✅ Namespace '$NAMESPACE' deleted successfully"
else
    echo "ℹ️  Namespace '$NAMESPACE' does not exist"
fi

# Remove hosts entry
remove_hosts_entry

# Clean up any persistent volumes (optional)
echo "Checking for GitLab persistent volumes..."
PVS=$(kubectl get pv -o name 2>/dev/null | grep -i gitlab || true)
if [[ -n "$PVS" ]]; then
    read -p "Found GitLab persistent volumes. Delete them? (y/n): " pv_confirm
    if [[ "$pv_confirm" == "y" ]]; then
        echo "$PVS" | xargs kubectl delete
        echo "✅ GitLab persistent volumes deleted"
    fi
fi

# Docker cleanup (remove GitLab images to free space)
if command_exists docker; then
    read -p "Remove GitLab Docker images to free up space? (y/n): " docker_confirm
    if [[ "$docker_confirm" == "y" ]]; then
        echo "Removing GitLab Docker images..."
        docker images | grep -i gitlab | awk '{print $3}' | xargs -r docker rmi -f || true
        echo "✅ GitLab Docker images removed"
    fi
fi

# Minikube cluster deletion
read -p "Do you want to delete the entire Minikube cluster? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
    echo "Deleting Minikube cluster..."
    minikube delete
    echo "✅ Minikube cluster deleted"
else
    echo "ℹ️  Minikube cluster will remain intact"
    
    # Optional: Restart minikube to clean up any stuck resources
    read -p "Restart Minikube to clean up any stuck resources? (y/n): " restart_confirm
    if [[ "$restart_confirm" == "y" ]]; then
        echo "Restarting Minikube..."
        minikube stop
        minikube start
        echo "✅ Minikube restarted"
    fi
fi

echo ""
echo "🎉 GitLab cleanup completed successfully!"
echo ""
echo "Summary of actions taken:"
echo "  - Killed active minikube service tunnels"
echo "  - Uninstalled GitLab Helm release"
echo "  - Deleted GitLab namespace and resources"
echo "  - Removed hosts file entry"
echo "  - Optional: Cleaned up persistent volumes and Docker images"
echo "  - Optional: Minikube cluster management"
echo ""
echo "You can now run a fresh GitLab installation if needed."
