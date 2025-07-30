#!/bin/bash

set -e

# Configuration
NAMESPACE="gitlab"
MAX_WAIT_TIME=900  # 15 minutes in seconds
CHECK_INTERVAL=10  # Check every 10 seconds
VERBOSE=${1:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_initializing() {
    echo -e "${CYAN}🔄 $1${NC}"
}

print_verbose() {
    if [[ "$VERBOSE" == "verbose" ]]; then
        echo -e "${NC}$1${NC}"
    fi
}

echo "⏳ Waiting for GitLab pods to be ready..."
echo "Namespace: $NAMESPACE"
echo "Max wait time: $((MAX_WAIT_TIME / 60)) minutes"
echo "Check interval: $CHECK_INTERVAL seconds"

if [[ "$VERBOSE" == "verbose" ]]; then
    echo "Verbose mode enabled"
fi

echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    print_error "Namespace '$NAMESPACE' does not exist!"
    exit 1
fi

elapsed_time=0
last_status=""

while [ $elapsed_time -lt $MAX_WAIT_TIME ]; do
    # Get pod status
    pods_output=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods_output" ]; then
        print_warning "No pods found in namespace '$NAMESPACE'"
        sleep $CHECK_INTERVAL
        elapsed_time=$((elapsed_time + CHECK_INTERVAL))
        continue
    fi
    
    # Count pods by status (excluding gitlab-runner which may crash)
    total_pods=$(echo "$pods_output" | grep -v "gitlab-runner" | wc -l)
    ready_pods=$(echo "$pods_output" | grep -v "gitlab-runner" | grep -E "(Running|Completed)" | wc -l || echo "0")
    initializing_pods=$(echo "$pods_output" | grep -v "gitlab-runner" | grep -E "(Pending|ContainerCreating|PodInitializing|Init:)" | wc -l || echo "0")
    error_pods=$(echo "$pods_output" | grep -v "gitlab-runner" | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l || echo "0")
    
    # Create status summary
    if [ "$initializing_pods" -gt 0 ]; then
        current_status="$ready_pods/$total_pods ready, $initializing_pods initializing"
    else
        current_status="$ready_pods/$total_pods ready"
    fi
    
    if [ "$error_pods" -gt 0 ]; then
        current_status="$current_status, $error_pods errors"
    fi
    
    # Only print status if it changed or in verbose mode
    if [[ "$current_status" != "$last_status" ]] || [[ "$VERBOSE" == "verbose" ]]; then
        elapsed_minutes=$((elapsed_time / 60))
        elapsed_seconds=$((elapsed_time % 60))
        printf "⏱️  [%02d:%02d] %s\n" $elapsed_minutes $elapsed_seconds "$current_status"
        last_status="$current_status"
    fi
    
    # Show detailed pod status in verbose mode
    if [[ "$VERBOSE" == "verbose" ]]; then
        print_verbose "Pod details:"
        echo "$pods_output" | grep -v "gitlab-runner" | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            pod_status=$(echo "$line" | awk '{print $3}')
            
            case $pod_status in
                "Running"|"Completed")
                    print_verbose "  ✅ $pod_name: $pod_status"
                    ;;
                "Pending"|"ContainerCreating"|"PodInitializing")
                    print_verbose "  🔄 $pod_name: $pod_status"
                    ;;
                Init:*)
                    print_verbose "  🔄 $pod_name: $pod_status"
                    ;;
                "Error"|"CrashLoopBackOff"|"ImagePullBackOff")
                    print_verbose "  ❌ $pod_name: $pod_status"
                    ;;
                *)
                    print_verbose "  ❓ $pod_name: $pod_status"
                    ;;
            esac
        done
        echo ""
    fi
    
    # Check if all pods are ready
    if [ "$total_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
        print_success "All GitLab pods are ready! ($ready_pods/$total_pods)"
        echo ""
        print_status "Final pod status:"
        kubectl get pods -n "$NAMESPACE" | grep -v "gitlab-runner"
        exit 0
    fi
    
    # Only warn about errors if they persist (not just during initialization)
    if [ "$error_pods" -gt 0 ] && [ "$elapsed_time" -gt 120 ]; then
        print_warning "Detected $error_pods pod(s) with persistent errors after 2+ minutes"
        if [[ "$VERBOSE" == "verbose" ]]; then
            print_verbose "Pods with errors:"
            echo "$pods_output" | grep -v "gitlab-runner" | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)"
        fi
    fi
    
    # Show initialization progress for encouraging feedback
    if [ "$initializing_pods" -gt 0 ] && [[ "$VERBOSE" != "verbose" ]]; then
        if [ $((elapsed_time % 30)) -eq 0 ] && [ $elapsed_time -gt 0 ]; then
            print_initializing "GitLab is starting up... $initializing_pods pods still initializing"
        fi
    fi
    
    sleep $CHECK_INTERVAL
    elapsed_time=$((elapsed_time + CHECK_INTERVAL))
done

# Timeout reached
print_error "Timeout reached after $((MAX_WAIT_TIME / 60)) minutes"
print_warning "Current status: $current_status"
echo ""
print_status "Final pod status:"
kubectl get pods -n "$NAMESPACE"
echo ""
print_status "You can check individual pod logs with:"
echo "kubectl logs -n $NAMESPACE <pod-name>"
echo ""
print_status "GitLab might still be starting. You can continue and check manually."
exit 1
