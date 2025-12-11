#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deleting Kind cluster 'donfra-local'...${NC}"

if kind get clusters | grep -q "donfra-local"; then
    kind delete cluster --name donfra-local
    echo -e "${GREEN}Cluster deleted successfully!${NC}"
else
    echo -e "${YELLOW}Cluster 'donfra-local' does not exist${NC}"
fi
