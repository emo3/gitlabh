#!/bin/bash

set -e

echo "=== GitLab Cleanup Script ==="

# Define the namespace
NAMESPACE="gitlab"

# Check if the namespace exists
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Deleting GitLab namespace and all associated resources..."
  kubectl delete namespace "$NAMESPACE"
else
  echo "Namespace '$NAMESPACE' does not exist. No resources to delete."
fi

# Optionally, delete Minikube cluster if you want to clean everything
read -p "Do you want to delete the entire Minikube cluster? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
  echo "Deleting Minikube cluster..."
  minikube delete
else
  echo "Minikube cluster will remain intact."
fi

echo "Cleanup completed."
