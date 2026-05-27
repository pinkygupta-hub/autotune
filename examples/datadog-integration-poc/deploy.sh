#!/bin/bash
# Automated deployment script for Datadog Integration POC

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="datadog-poc"
APP_NAME="memory-monitor-app"
IMAGE_NAME="memory-monitor-app:latest"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Datadog Integration POC - Deployment Script           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=300
    local elapsed=0
    
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
    while [ $elapsed -lt $timeout ]; do
        if oc get pods -n "$namespace" -l "$label" 2>/dev/null | grep -q "Running"; then
            echo -e "${GREEN}✓ Pods are ready${NC}"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo -e "${RED}✗ Timeout waiting for pods${NC}"
    return 1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists oc; then
    echo -e "${RED}✗ oc CLI not found. Please install OpenShift CLI${NC}"
    exit 1
fi
echo -e "${GREEN}✓ oc CLI found${NC}"

if ! command_exists docker && ! command_exists podman; then
    echo -e "${RED}✗ Neither docker nor podman found. Please install one${NC}"
    exit 1
fi
CONTAINER_CMD=$(command_exists docker && echo "docker" || echo "podman")
echo -e "${GREEN}✓ ${CONTAINER_CMD} found${NC}"

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift. Please run 'oc login' first${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Logged in to OpenShift as $(oc whoami)${NC}"

# Check for Datadog API keys
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo -e "${YELLOW}⚠ Datadog API keys not set${NC}"
    echo "Please set the following environment variables:"
    echo "  export DD_API_KEY='your-api-key'"
    echo "  export DD_APP_KEY='your-app-key'"
    echo ""
    read -p "Do you want to enter them now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter DD_API_KEY: " DD_API_KEY
        read -p "Enter DD_APP_KEY: " DD_APP_KEY
        export DD_API_KEY
        export DD_APP_KEY
    else
        echo -e "${RED}✗ Cannot proceed without API keys${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Datadog API keys configured${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Building Application Image${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd sample-app
echo "Building ${IMAGE_NAME}..."
$CONTAINER_CMD build -t ${IMAGE_NAME} .
echo -e "${GREEN}✓ Image built successfully${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Deploying Application to OpenShift${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd ../k8s

# Create namespace
echo "Creating namespace ${NAMESPACE}..."
oc apply -f namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"

# Deploy application
echo "Deploying application..."
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f servicemonitor.yaml
echo -e "${GREEN}✓ Application deployed${NC}"

# Wait for pods to be ready
wait_for_pods "$NAMESPACE" "app=memory-monitor"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Configuring Datadog Agent${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

cd ../datadog

# Check if Datadog operator is installed
if ! oc get crd datadogagents.datadoghq.com &>/dev/null; then
    echo -e "${YELLOW}⚠ Datadog Operator not found${NC}"
    echo "Please install the Datadog Operator from OperatorHub:"
    echo "  Operators → OperatorHub → Search 'Datadog Operator' → Install"
    echo ""
    read -p "Press Enter after installing the operator..." 
fi

# Update API keys in the configuration
echo "Configuring Datadog Agent..."
TEMP_FILE=$(mktemp)
sed "s/<YOUR_DATADOG_API_KEY>/${DD_API_KEY}/g" datadog-operator.yaml | \
sed "s/<YOUR_DATADOG_APP_KEY>/${DD_APP_KEY}/g" > "$TEMP_FILE"

oc apply -f "$TEMP_FILE"
rm "$TEMP_FILE"
echo -e "${GREEN}✓ Datadog Agent configured${NC}"

# Wait for Datadog agent to be ready
wait_for_pods "datadog" "app=datadog-agent"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Creating Datadog Monitor and Dashboard${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Wait a bit for metrics to start flowing
echo "Waiting 30 seconds for metrics to start flowing..."
sleep 30

# Create monitor and dashboard
chmod +x create-datadog-resources.sh
./create-datadog-resources.sh

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Deployment Completed Successfully!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Verify the application is running:"
echo -e "   ${BLUE}oc get pods -n ${NAMESPACE}${NC}"
echo ""
echo "2. Check metrics endpoint:"
echo -e "   ${BLUE}oc port-forward -n ${NAMESPACE} svc/memory-monitor-service 8080:8080${NC}"
echo -e "   ${BLUE}curl http://localhost:8080/metrics${NC}"
echo ""
echo "3. Trigger memory threshold alert:"
echo -e "   ${BLUE}curl http://localhost:8080/simulate-load${NC}"
echo ""
echo "4. View in Datadog:"
echo "   - Check the dashboard and monitor URLs from the output above"
echo "   - Wait 5-10 minutes for alerts to appear"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "   - Application logs: ${BLUE}oc logs -n ${NAMESPACE} -l app=memory-monitor${NC}"
echo "   - Datadog agent logs: ${BLUE}oc logs -n datadog -l app=datadog-agent${NC}"
echo ""
echo -e "${GREEN}Happy monitoring! 🎉${NC}"

# Made with Bob
