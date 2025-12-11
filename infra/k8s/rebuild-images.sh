#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Rebuilding and reloading Docker images...${NC}"

cd ../..

# Build API image
echo -e "${YELLOW}Building donfra-api image...${NC}"
docker build -t donfra-api:dev -f donfra-api/Dockerfile donfra-api/

# Build WS image
echo -e "${YELLOW}Building donfra-ws image...${NC}"
docker build -t donfra-ws:dev -f donfra-ws/Dockerfile donfra-ws/

# Build UI image (optional - if you want to use local build instead of Docker Hub)
# echo -e "${YELLOW}Building donfra-ui image...${NC}"
# docker build -t donfra-ui:dev -f donfra-ui/Dockerfile donfra-ui/

echo -e "${YELLOW}Loading images into Kind cluster...${NC}"
kind load docker-image donfra-api:dev --name donfra-local
kind load docker-image donfra-ws:dev --name donfra-local
# kind load docker-image donfra-ui:dev --name donfra-local

echo -e "${YELLOW}Restarting deployments...${NC}"
kubectl rollout restart deployment/api -n donfra
kubectl rollout restart deployment/ws -n donfra
# kubectl rollout restart deployment/ui -n donfra

echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/api -n donfra
kubectl rollout status deployment/ws -n donfra
# kubectl rollout status deployment/ui -n donfra

echo -e "${GREEN}Images rebuilt and deployments restarted!${NC}"
