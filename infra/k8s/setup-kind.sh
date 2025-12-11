#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setting up Donfra on Kind cluster${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Error: kind is not installed${NC}"
    echo "Please install kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating Kind cluster...${NC}"
if kind get clusters | grep -q "donfra-local"; then
    echo -e "${YELLOW}Cluster 'donfra-local' already exists. Deleting...${NC}"
    kind delete cluster --name donfra-local
fi
kind create cluster --config kind-config.yaml

echo -e "${YELLOW}Step 2: Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo -e "${YELLOW}Step 3: Waiting for Ingress Controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo -e "${YELLOW}Step 4: Building Docker images...${NC}"
cd ../..

# Build API image
echo -e "${YELLOW}Building donfra-api image...${NC}"
docker build -t donfra-api:dev -f donfra-api/Dockerfile donfra-api/

# Build WS image
echo -e "${YELLOW}Building donfra-ws image...${NC}"
docker build -t donfra-ws:dev -f donfra-ws/Dockerfile donfra-ws/

# Note: UI image is already available from Docker Hub (doneowth/donfra-ui:1.0.4)
echo -e "${YELLOW}UI image will be pulled from Docker Hub${NC}"

echo -e "${YELLOW}Step 5: Loading images into Kind cluster...${NC}"
kind load docker-image donfra-api:dev --name donfra-local
kind load docker-image donfra-ws:dev --name donfra-local

echo -e "${YELLOW}Step 6: Applying Kubernetes manifests...${NC}"
cd infra/k8s/base

# Apply in order
kubectl apply -f namespace.yaml

# Infrastructure
kubectl apply -f postgres-configmap.yaml
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-init-configmap.yaml
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

kubectl apply -f redis-pvc.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

kubectl apply -f jaeger-deployment.yaml
kubectl apply -f jaeger-service.yaml

# Application
kubectl apply -f api-configmap.yaml
kubectl apply -f api-secret.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service.yaml

kubectl apply -f ws-configmap.yaml
kubectl apply -f ws-deployment.yaml
kubectl apply -f ws-service.yaml

kubectl apply -f ui-configmap.yaml
kubectl apply -f ui-deployment.yaml
kubectl apply -f ui-service.yaml

# Ingress
kubectl apply -f ingress.yaml

echo -e "${YELLOW}Step 7: Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=postgres \
  --timeout=120s

echo -e "${YELLOW}Step 8: Waiting for Redis to be ready...${NC}"
kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=redis \
  --timeout=60s

echo -e "${YELLOW}Step 9: Waiting for application pods to be ready...${NC}"
kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=api \
  --timeout=120s

kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=ws \
  --timeout=60s

kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=ui \
  --timeout=120s

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Add this line to your /etc/hosts file:${NC}"
echo -e "${GREEN}127.0.0.1 donfra.local${NC}"
echo ""
echo -e "${YELLOW}Access the application at:${NC}"
echo -e "${GREEN}http://donfra.local${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  kubectl get pods -n donfra              # Check pod status"
echo "  kubectl logs -f -n donfra <pod-name>    # View logs"
echo "  kubectl port-forward -n donfra svc/postgres 5432:5432  # Access PostgreSQL"
echo "  kubectl port-forward -n donfra svc/jaeger 16686:16686  # Access Jaeger UI"
echo ""
