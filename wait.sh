#!/bin/bash

# Set the timeout duration (in seconds)
TIMEOUT=300 # 5 minutes
START_TIME=$(date +%s)

# Function to check the status of the pods
check_pods() {
    # Get the status of all pods
    kubectl get pods --no-headers | awk '{print $3}' | sort | uniq
}

# Wait until all pods are in a "Running" or "Completed" state
while true; do
    # Get the current pod statuses
    statuses=$(check_pods)

    # Check if there are any pods that are not "Running" or "Completed"
    if [[ ! "$statuses" =~ "Pending" && ! "$statuses" =~ "Init" && ! "$statuses" =~ "CrashLoopBackOff" && ! "$statuses" =~ "ContainerCreating" && ! "$statuses" =~ "PodInitializing" ]]; then
        echo "All pods are ready!"
        exit 0
    fi

    # Print the current statuses
    echo "Current pod statuses: $statuses"
    
    # Check if the timeout has been reached
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echo "Timeout reached: Pods did not become ready within 5 minutes."
        exit 1
    fi

    # Wait for a few seconds before checking again
    sleep 5
done
