#!/bin/bash

# Set the namespace where GitLab is installed
NAMESPACE="default"  # Change this if your GitLab is in a different namespace

# Optional: Set a label selector if you want to filter specific PVCs
# LABEL_SELECTOR="app=gitlab"  # Uncomment and modify if you have specific labels

# List all PVCs in the specified namespace
echo "Listing all PVCs in the namespace: $NAMESPACE"
kubectl get pvc -n $NAMESPACE

# Delete all PVCs (uncomment the line below if you want to filter by label)
# kubectl delete pvc -l $LABEL_SELECTOR -n $NAMESPACE

# Delete all PVCs without filtering
echo "Deleting all PVCs in the namespace: $NAMESPACE"
kubectl delete pvc --all -n $NAMESPACE

echo "All PVCs have been deleted."
