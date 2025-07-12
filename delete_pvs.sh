#!/bin/bash

# Get all Persistent Volumes and filter for those in the Released state
released_pvs=$(kubectl get pv --no-headers | grep Released | awk '{print $1}')

# Check if there are any released PVs
if [ -z "$released_pvs" ]; then
    echo "No Persistent Volumes in the Released state found."
else
    # Loop through each released PV and delete it
    for pv in $released_pvs; do
        echo "Deleting Persistent Volume: $pv"
        kubectl delete pv "$pv"
    done
    echo "All released Persistent Volumes have been deleted."
fi
