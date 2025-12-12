#!/bin/bash
set -e

echo "=== Installing Istio Ambient Mode with Gateway API ==="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Download istioctl
echo -e "${YELLOW}[1/6] Downloading istioctl...${NC}"
ISTIO_VERSION="1.28.1"
if [ ! -f "$HOME/.istioctl/bin/istioctl" ]; then
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
    mkdir -p $HOME/.istioctl/bin
    mv istio-${ISTIO_VERSION}/bin/istioctl $HOME/.istioctl/bin/
    rm -rf istio-${ISTIO_VERSION}
    echo -e "${GREEN}✓ istioctl installed to $HOME/.istioctl/bin/istioctl${NC}"
else
    echo -e "${GREEN}✓ istioctl already exists${NC}"
fi

export PATH=$HOME/.istioctl/bin:$PATH

# Step 2: Install Gateway API CRDs
echo -e "${YELLOW}[2/6] Installing Gateway API CRDs...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
echo -e "${GREEN}✓ Gateway API CRDs installed${NC}"

# Step 3: Install Istio with Ambient profile
echo -e "${YELLOW}[3/6] Installing Istio (Ambient profile)...${NC}"
istioctl install --set profile=ambient \
    --set components.ingressGateways[0].enabled=false \
    --set components.egressGateways[0].enabled=false \
    -y

echo -e "${GREEN}✓ Istio installed in ambient mode${NC}"

# Step 4: Verify Istio installation
echo -e "${YELLOW}[4/6] Verifying Istio components...${NC}"
kubectl get pods -n istio-system
kubectl get daemonset -n istio-system

# Step 5: Check if donfra namespace exists and enable ambient mode
echo -e "${YELLOW}[5/6] Checking donfra namespace...${NC}"
if kubectl get namespace donfra &> /dev/null; then
    echo "Enabling ambient mode for donfra namespace..."
    kubectl label namespace donfra istio.io/dataplane-mode=ambient --overwrite
    echo -e "${GREEN}✓ Ambient mode enabled for donfra namespace${NC}"
else
    echo -e "${YELLOW}⚠ donfra namespace not found (will be created later)${NC}"
    echo -e "${YELLOW}  Ambient mode will be enabled after namespace creation${NC}"
fi

# Step 6: Summary
echo -e "${YELLOW}[6/6] Installation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Istio ${ISTIO_VERSION} installed (Ambient Mode)${NC}"
echo -e "${GREEN}✓ Gateway API CRDs installed${NC}"
echo -e "${GREEN}✓ donfra namespace labeled for ambient mesh${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy Gateway: kubectl apply -f gateway.yaml"
echo "  2. Deploy HTTPRoute: kubectl apply -f httproute.yaml"
echo "  3. Remove old Ingress: kubectl delete ingress donfra-ingress -n donfra"
echo ""
echo "Add istioctl to your PATH:"
echo "  export PATH=\$HOME/.istioctl/bin:\$PATH"
echo "  # Add to ~/.bashrc or ~/.zshrc to make it permanent"
