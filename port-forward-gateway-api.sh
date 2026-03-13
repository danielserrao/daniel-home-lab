#!/bin/bash

NAMESPACE="gateway-api"
SERVICE="gateway-api-nginx"
TIMEOUT=240  # seconds
INTERVAL=5   # seconds

# Initialize ports
LOCAL_PORT=""
REMOTE_PORT=""

# Function to show usage
usage() {
    echo "Usage: $0 -l <local_port> -r <remote_port>"
    exit 1
}

# Parse flags
while getopts ":l:r:" opt; do
    case $opt in
        l) LOCAL_PORT="$OPTARG" ;;
        r) REMOTE_PORT="$OPTARG" ;;
        *) usage ;;
    esac
done

# Exit with error if ports are not set
if [ -z "$LOCAL_PORT" ] || [ -z "$REMOTE_PORT" ]; then
    echo "Error: Both LOCAL_PORT (-l) and REMOTE_PORT (-r) must be set."
    usage
fi

echo "Waiting for Gateway API to be ready..."

elapsed=0
while true; do
    # Check if the service endpoints are ready
    ready=$(kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    
    if [ -n "$ready" ]; then
        echo "Gateway API is ready!"
        break
    fi

    if [ "$elapsed" -ge "$TIMEOUT" ]; then
        echo "Timeout reached ($TIMEOUT seconds). Exiting."
        exit 1
    fi

    echo "Waiting for Gateway API to be ready..."
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

# Forward the port
echo "Starting port-forward from local port $LOCAL_PORT to remote port $REMOTE_PORT..."
kubectl port-forward --namespace "$NAMESPACE" svc/"$SERVICE" "$LOCAL_PORT:$REMOTE_PORT"