#!/bin/bash

# This script helps to update your /etc/hosts file by adding or updating
# an entry for 'gitlab.example.com' to point to your Minikube IP address.
# This is crucial for accessing your local GitLab instance via HTTPS.

echo "--- Updating /etc/hosts for GitLab ---"

# Define the hostname to be added/updated
GITLAB_HOSTNAME="gitlab.example.com"
HOSTS_FILE="/etc/hosts"

# --- Get Minikube IP ---
echo ""
echo "Attempting to get Minikube IP address..."
MINIKUBE_IP=$(minikube ip 2>/dev/null)

if [ -z "$MINIKUBE_IP" ]; then
  echo "Error: Could not determine Minikube IP. Is Minikube running?"
  echo "Please ensure Minikube is started: 'minikube start --memory 8192 --cpus 4 --driver=docker'"
  exit 1
else
  echo "Minikube IP detected: $MINIKUBE_IP"
fi

# --- Check and Update /etc/hosts ---
echo ""
echo "Checking and updating $HOSTS_FILE..."

# Check if the entry already exists
if grep -q "$GITLAB_HOSTNAME" "$HOSTS_FILE"; then
  echo "Entry for $GITLAB_HOSTNAME found. Updating IP address..."
  # Use sudo to modify the hosts file
  sudo sed -i.bak "/$GITLAB_HOSTNAME/c\\$MINIKUBE_IP\t$GITLAB_HOSTNAME" "$HOSTS_FILE"
  echo "Updated entry for $GITLAB_HOSTNAME in $HOSTS_FILE."
  echo "Original file backed up as $HOSTS_FILE.bak"
else
  echo "Entry for $GITLAB_HOSTNAME not found. Adding new entry..."
  # Use sudo to append to the hosts file
  echo -e "$MINIKUBE_IP\t$GITLAB_HOSTNAME" | sudo tee -a "$HOSTS_FILE" > /dev/null
  echo "Added new entry for $GITLAB_HOSTNAME in $HOSTS_FILE."
fi

echo ""
echo "--- /etc/hosts update complete! ---"
echo "You should now be able to access GitLab at https://$GITLAB_HOSTNAME"
echo "Remember to accept the self-signed certificate warning in your browser."
echo ""
echo "To verify the entry, you can run: cat $HOSTS_FILE"
echo "To test DNS resolution, you can run: ping -c 1 $GITLAB_HOSTNAME"
