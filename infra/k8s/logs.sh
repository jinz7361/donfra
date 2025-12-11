#!/bin/bash

# Colors for output
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo -e "${YELLOW}Usage: ./logs.sh <service>${NC}"
    echo "Available services: api, ws, ui, postgres, redis, jaeger"
    exit 1
fi

case $SERVICE in
    api|ws|ui|postgres|redis|jaeger)
        POD=$(kubectl get pods -n donfra -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}')
        if [ -z "$POD" ]; then
            echo "No pod found for service: $SERVICE"
            exit 1
        fi
        echo -e "${YELLOW}Showing logs for $SERVICE ($POD)${NC}"
        kubectl logs -f -n donfra $POD
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Available services: api, ws, ui, postgres, redis, jaeger"
        exit 1
        ;;
esac
