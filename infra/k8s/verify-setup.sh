#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Donfra Setup Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check cluster exists
echo -e "${YELLOW}[1/8] Checking Kind cluster...${NC}"
if kind get clusters | grep -q "donfra-local"; then
  echo -e "${GREEN}✓ Kind cluster 'donfra-local' exists${NC}"
else
  echo -e "${RED}✗ Kind cluster 'donfra-local' not found${NC}"
  exit 1
fi

# Check namespace
echo -e "${YELLOW}[2/8] Checking namespace...${NC}"
if kubectl get namespace donfra &> /dev/null; then
  echo -e "${GREEN}✓ Namespace 'donfra' exists${NC}"

  # Check ambient mode label
  AMBIENT_LABEL=$(kubectl get namespace donfra -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}')
  if [ "$AMBIENT_LABEL" = "ambient" ]; then
    echo -e "${GREEN}✓ Ambient mode enabled on namespace${NC}"
  else
    echo -e "${RED}✗ Ambient mode not enabled${NC}"
  fi
else
  echo -e "${RED}✗ Namespace 'donfra' not found${NC}"
  exit 1
fi

# Check pods
echo -e "${YELLOW}[3/8] Checking pod status...${NC}"
PODS_NOT_READY=$(kubectl get pods -n donfra --no-headers | grep -v "Running" | grep -v "Completed" || true)
if [ -z "$PODS_NOT_READY" ]; then
  echo -e "${GREEN}✓ All pods are running${NC}"
  kubectl get pods -n donfra --no-headers | awk '{print "  " $1 " - " $3}'
else
  echo -e "${RED}✗ Some pods are not ready:${NC}"
  echo "$PODS_NOT_READY"
fi

# Check Gateway deployment
echo -e "${YELLOW}[4/8] Checking Gateway configuration...${NC}"
if kubectl get deployment donfra-gateway-istio -n donfra &> /dev/null; then
  echo -e "${GREEN}✓ Gateway deployment exists${NC}"

  # Check Gateway pod node placement
  GATEWAY_NODE=$(kubectl get pods -n donfra -l gateway.networking.k8s.io/gateway-name=donfra-gateway -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || echo "none")
  if [[ "$GATEWAY_NODE" == *"control-plane"* ]]; then
    echo -e "${GREEN}✓ Gateway pod on control-plane: ${GATEWAY_NODE}${NC}"
  else
    echo -e "${RED}✗ Gateway pod on wrong node: ${GATEWAY_NODE}${NC}"
  fi

  # Check hostPort configuration
  HOST_PORT=$(kubectl get deployment donfra-gateway-istio -n donfra -o jsonpath='{.spec.template.spec.containers[0].ports[?(@.name=="http")].hostPort}' 2>/dev/null || echo "none")
  if [ "$HOST_PORT" = "80" ]; then
    echo -e "${GREEN}✓ hostPort 80 configured${NC}"
  else
    echo -e "${RED}✗ hostPort not configured (current: ${HOST_PORT})${NC}"
  fi

  # Check tolerations
  TOLERATIONS=$(kubectl get deployment donfra-gateway-istio -n donfra -o jsonpath='{.spec.template.spec.tolerations}' 2>/dev/null || echo "[]")
  if [[ "$TOLERATIONS" == *"control-plane"* ]]; then
    echo -e "${GREEN}✓ Tolerations configured${NC}"
  else
    echo -e "${RED}✗ Tolerations not configured${NC}"
  fi
else
  echo -e "${RED}✗ Gateway deployment not found${NC}"
fi

# Check Gateway and HTTPRoute resources
echo -e "${YELLOW}[5/8] Checking Gateway API resources...${NC}"
if kubectl get gateway donfra-gateway -n donfra &> /dev/null; then
  GATEWAY_STATUS=$(kubectl get gateway donfra-gateway -n donfra -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  if [ "$GATEWAY_STATUS" = "True" ]; then
    echo -e "${GREEN}✓ Gateway is programmed${NC}"
  else
    echo -e "${YELLOW}⚠ Gateway status: ${GATEWAY_STATUS}${NC}"
  fi
else
  echo -e "${RED}✗ Gateway resource not found${NC}"
fi

if kubectl get httproute -n donfra &> /dev/null; then
  ROUTE_COUNT=$(kubectl get httproute -n donfra --no-headers | wc -l)
  echo -e "${GREEN}✓ HTTPRoute(s) configured: ${ROUTE_COUNT}${NC}"
else
  echo -e "${RED}✗ HTTPRoute not found${NC}"
fi

# Check Prometheus targets
echo -e "${YELLOW}[6/8] Checking Prometheus scrape targets...${NC}"
if kubectl get pod -n donfra -l app=prometheus &> /dev/null; then
  echo -e "${GREEN}✓ Prometheus pod exists${NC}"
  # Note: Can't easily check targets without port-forward, skip for now
else
  echo -e "${RED}✗ Prometheus pod not found${NC}"
fi

# Check Grafana dashboard
echo -e "${YELLOW}[7/8] Checking Grafana configuration...${NC}"
if kubectl get configmap grafana-dashboards -n donfra &> /dev/null; then
  echo -e "${GREEN}✓ Grafana dashboard ConfigMap exists${NC}"
else
  echo -e "${RED}✗ Grafana dashboard ConfigMap not found${NC}"
fi

# Check connectivity
echo -e "${YELLOW}[8/8] Testing Gateway connectivity...${NC}"
if ! grep -q "donfra.local" /etc/hosts; then
  echo -e "${YELLOW}⚠ Warning: 'donfra.local' not in /etc/hosts${NC}"
  echo -e "${YELLOW}Add this line: 127.0.0.1 donfra.local${NC}"
  TEST_URL="http://localhost"
else
  TEST_URL="http://donfra.local"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
  echo -e "${GREEN}✓ Gateway accessible at ${TEST_URL} (HTTP ${HTTP_CODE})${NC}"
else
  echo -e "${RED}✗ Gateway not accessible at ${TEST_URL} (HTTP ${HTTP_CODE})${NC}"
  echo -e "${YELLOW}Check: kubectl get pods -n donfra -l istio.io/gateway-name=donfra-gateway${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verification Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "${GREEN}Application:    ${TEST_URL}${NC}"
echo -e "${GREEN}Grafana:        ${TEST_URL}/grafana${NC}"
echo -e "${GREEN}Prometheus:     ${TEST_URL}/prometheus${NC}"
echo -e "${GREEN}Jaeger:         ${TEST_URL}/jaeger${NC}"
echo ""
