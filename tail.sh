#!/bin/bash

# This script tails the logs of a specified Kubernetes pod, allowing for regular expression matching.
# It requires `kubectl` to be installed and configured to connect to your Kubernetes cluster.

# Function to display usage information
usage() {
  echo "Usage: $0 [pod-name-regex]"
  echo "If no regex is provided, a list of all pods will be displayed."
  echo "Example: $0 'gitlab.*'"
  echo "Example: $0 'my-app-deployment-.*'"
  exit 1
}

# Function to list all pods
list_all_pods() {
  echo "--- All available pods ---"
  kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null
  echo "--------------------------"
}

# Check if a pod name regex is provided as an argument
if [ -z "$1" ]; then
  echo "No pod name regex provided. Displaying all available pods."
  list_all_pods
  usage # Display usage and exit after listing pods
fi

POD_REGEX="$1"

echo "Searching for pods matching regex: '$POD_REGEX'"

# Get all pod names and filter them using the provided regex.
# The 'grep -v "^$"' command ensures that any empty lines are removed,
# preventing false positives when counting matches.
# Use 'tr -d '\n'' to remove newlines for a more accurate empty check,
# then pipe to 'tr -s '\n'' to restore single newlines for proper line counting.
MATCHING_PODS_RAW=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep -E "$POD_REGEX" | grep -v "^$")

# Check if MATCHING_PODS_RAW is truly empty (contains no characters)
if [ -z "$MATCHING_PODS_RAW" ]; then
  NUM_MATCHING_PODS=0
  MATCHING_PODS="" # Ensure MATCHING_PODS is empty if no matches
else
  # If not empty, then count the lines properly
  MATCHING_PODS=$(echo "$MATCHING_PODS_RAW" | tr -s '\n') # Normalize newlines
  NUM_MATCHING_PODS=$(echo "$MATCHING_PODS" | wc -l)
fi


if [ "$NUM_MATCHING_PODS" -eq 0 ]; then
  echo "No pods found matching the regex '$POD_REGEX'."
  list_all_pods # List all pods if no match is found
  exit 1
elif [ "$NUM_MATCHING_PODS" -eq 1 ]; then
  POD_NAME="$MATCHING_PODS"
  echo "Found one matching pod: $POD_NAME"
else
  echo "Multiple pods found matching the regex '$POD_REGEX':"
  echo "$MATCHING_PODS"
  echo "More than one pod matched. Please refine your regex for a single match, or select a pod manually."
  exit 1 # Exit if multiple pods are found, as requested
fi

# Final check to ensure POD_NAME is not empty before attempting to tail logs
if [ -z "$POD_NAME" ]; then
  echo "Error: A valid pod name could not be determined. Exiting."
  exit 1
fi

echo "Tailing logs for pod: $POD_NAME"
echo "Press Ctrl+C to stop tailing."

# Use kubectl to tail the logs of the selected pod
# The '-f' flag streams the logs, similar to 'tail -f'
kubectl logs -f "$POD_NAME"

# Check the exit status of the kubectl command
if [ $? -ne 0 ]; then
  echo "Error: Could not tail logs for pod '$POD_NAME'."
  echo "Please ensure the pod name is correct and you have access to the cluster."
fi
