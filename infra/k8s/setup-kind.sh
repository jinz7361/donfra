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

echo -e "${YELLOW}Step 2: Installing Istio with Ambient Mode...${NC}"
if [ -f "./install-istio-ambient.sh" ]; then
    bash ./install-istio-ambient.sh
else
    echo -e "${RED}Error: install-istio-ambient.sh not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Building Docker images...${NC}"
cd ../..

# Build API image
echo -e "${YELLOW}Building donfra-api image...${NC}"
docker build -t donfra-api:dev -f donfra-api/Dockerfile donfra-api/

# Build WS image
echo -e "${YELLOW}Building donfra-ws image...${NC}"
docker build -t donfra-ws:dev -f donfra-ws/Dockerfile donfra-ws/

# Note: UI image is already available from Docker Hub (doneowth/donfra-ui:1.0.4)
echo -e "${YELLOW}UI image will be pulled from Docker Hub${NC}"

echo -e "${YELLOW}Step 4: Loading images into Kind cluster...${NC}"
kind load docker-image donfra-api:dev --name donfra-local
kind load docker-image donfra-ws:dev --name donfra-local

echo -e "${YELLOW}Step 5: Applying Kubernetes manifests...${NC}"
cd infra/k8s/base

# Apply in order
kubectl apply -f namespace.yaml

# Enable Istio ambient mode for donfra namespace
echo -e "${YELLOW}Enabling Istio ambient mode for donfra namespace...${NC}"
kubectl label namespace donfra istio.io/dataplane-mode=ambient --overwrite
echo -e "${GREEN}✓ Ambient mode enabled${NC}"

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

# Observability Stack
echo -e "${YELLOW}Deploying observability stack (OTel, Prometheus, Loki, Grafana)...${NC}"
kubectl apply -f otel-collector-configmap.yaml
kubectl apply -f otel-collector-deployment.yaml
kubectl apply -f otel-collector-service.yaml

kubectl apply -f prometheus-configmap.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f prometheus-service.yaml
kubectl apply -f prometheus-rbac.yaml

kubectl apply -f loki-configmap.yaml
kubectl apply -f loki-deployment.yaml
kubectl apply -f loki-service.yaml

kubectl apply -f grafana-configmap.yaml
kubectl apply -f grafana-dashboards-provisioning.yaml
kubectl apply -f grafana-dashboard-configmap.yaml
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-service.yaml

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

# Gateway API (Istio)
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

echo -e "${YELLOW}Step 6: Configuring Gateway for Kind (hostPort and node scheduling)...${NC}"
# Wait for Gateway deployment to be created by Istio
echo -e "${YELLOW}Waiting for Istio to create Gateway deployment...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30
until kubectl get deployment donfra-gateway-istio -n donfra &> /dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}Error: Gateway deployment not created after ${MAX_RETRIES} seconds${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Waiting for Gateway deployment... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
  sleep 1
done
echo -e "${GREEN}✓ Gateway deployment created${NC}"

# Apply patch to schedule on control-plane node with hostPort
echo -e "${YELLOW}Applying Gateway configuration patch...${NC}"
kubectl patch deployment donfra-gateway-istio -n donfra --patch-file gateway-deployment-patch.yaml
echo -e "${GREEN}✓ Gateway patch applied${NC}"

# Wait for deployment rollout to complete (ensures old pods are terminated)
echo -e "${YELLOW}Waiting for Gateway deployment rollout to complete...${NC}"
kubectl rollout status deployment/donfra-gateway-istio -n donfra --timeout=180s
echo -e "${GREEN}✓ Gateway deployment rollout complete${NC}"

# Verify Gateway is on control-plane node
GATEWAY_NODE=$(kubectl get pods -n donfra -l gateway.networking.k8s.io/gateway-name=donfra-gateway -o jsonpath='{.items[0].spec.nodeName}')
if [[ "$GATEWAY_NODE" == *"control-plane"* ]]; then
  echo -e "${GREEN}✓ Gateway pod running on control-plane node: ${GATEWAY_NODE}${NC}"
else
  echo -e "${RED}⚠ Warning: Gateway pod is on ${GATEWAY_NODE}, not control-plane${NC}"
  echo -e "${YELLOW}Gateway may not be accessible. Check kind-config.yaml port mappings.${NC}"
fi

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

echo -e "${YELLOW}Step 9: Waiting for observability stack to be ready...${NC}"
kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=otel-collector \
  --timeout=90s

kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=prometheus \
  --timeout=90s

kubectl wait --namespace donfra \
  --for=condition=ready pod \
  --selector=app=grafana \
  --timeout=90s

echo -e "${YELLOW}Step 10: Waiting for application pods to be ready...${NC}"
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

echo -e "${YELLOW}Step 11: Testing Gateway connectivity...${NC}"
# Check if donfra.local resolves
if ! grep -q "donfra.local" /etc/hosts; then
  echo -e "${YELLOW}⚠ Warning: 'donfra.local' not found in /etc/hosts${NC}"
  echo -e "${YELLOW}Testing with localhost instead...${NC}"
  TEST_URL="http://localhost"
else
  TEST_URL="http://donfra.local"
fi

# Test connectivity with retries
RETRY_COUNT=0
MAX_RETRIES=10
until curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" | grep -q "200\|301\|302"; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}⚠ Warning: Could not connect to ${TEST_URL} after ${MAX_RETRIES} attempts${NC}"
    echo -e "${YELLOW}Gateway may still be initializing. Please check manually.${NC}"
    break
  fi
  echo -e "${YELLOW}Testing connectivity... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
  sleep 2
done

if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
  echo -e "${GREEN}✓ Gateway is accessible at ${TEST_URL}${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Add this line to your /etc/hosts file:${NC}"
echo -e "${GREEN}127.0.0.1 donfra.local${NC}"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "${GREEN}Application:    http://donfra.local${NC}"
echo -e "${GREEN}Grafana:        http://donfra.local/grafana${NC}"
echo -e "${GREEN}Prometheus:     http://donfra.local/prometheus${NC}"
echo -e "${GREEN}Jaeger:         http://donfra.local/jaeger${NC}"
echo ""
echo -e "${YELLOW}Grafana Dashboard:${NC}"
echo "  Dashboard: 'Donfra Platform Overview'"
echo "  Auth: Anonymous (no login required)"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  kubectl get pods -n donfra              # Check pod status"
echo "  kubectl logs -f -n donfra <pod-name>    # View logs"
echo "  kubectl get gateway -n donfra           # Check Istio Gateway status"
echo "  kubectl get httproute -n donfra         # Check routes"
echo ""
echo -e "${YELLOW}Metrics instrumented:${NC}"
echo "  - donfra_room_opened_total"
echo "  - donfra_room_closed_total"
echo "  - donfra_room_joins_total"
echo "  - donfra_code_executions_total"
echo "  - donfra_lessons_created_total"
echo "  - HTTP request duration & count"
echo "  - Database connection metrics"
echo ""
