#!/bin/bash
# Script to create Datadog monitor and dashboard using the Datadog API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required environment variables are set
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo -e "${RED}Error: DD_API_KEY and DD_APP_KEY environment variables must be set${NC}"
    echo "Get your keys from: https://us5.datadoghq.com/organization-settings/api-keys"
    echo ""
    echo "Usage:"
    echo "  export DD_API_KEY='your-api-key'"
    echo "  export DD_APP_KEY='your-app-key'"
    echo "  ./create-datadog-resources.sh"
    exit 1
fi

# Datadog site (default to us5.datadoghq.com)
DD_SITE="${DD_SITE:-us5.datadoghq.com}"
API_URL="https://api.${DD_SITE}/api/v1"

echo -e "${GREEN}Creating Datadog resources...${NC}"
echo "API URL: $API_URL"
echo ""

# Create Monitor
echo -e "${YELLOW}Creating Datadog Monitor...${NC}"
MONITOR_RESPONSE=$(curl -s -X POST "${API_URL}/monitor" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -d @monitor-config.json)

MONITOR_ID=$(echo $MONITOR_RESPONSE | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -n "$MONITOR_ID" ]; then
    echo -e "${GREEN}✓ Monitor created successfully!${NC}"
    echo "  Monitor ID: $MONITOR_ID"
    echo "  View at: https://app.${DD_SITE}/monitors/${MONITOR_ID}"
else
    echo -e "${RED}✗ Failed to create monitor${NC}"
    echo "Response: $MONITOR_RESPONSE"
fi

echo ""

# Create Dashboard
echo -e "${YELLOW}Creating Datadog Dashboard...${NC}"
DASHBOARD_RESPONSE=$(curl -s -X POST "${API_URL}/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -d @dashboard-config.json)

DASHBOARD_ID=$(echo $DASHBOARD_RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$DASHBOARD_ID" ]; then
    echo -e "${GREEN}✓ Dashboard created successfully!${NC}"
    echo "  Dashboard ID: $DASHBOARD_ID"
    echo "  View at: https://app.${DD_SITE}/dashboard/${DASHBOARD_ID}"
else
    echo -e "${RED}✗ Failed to create dashboard${NC}"
    echo "Response: $DASHBOARD_RESPONSE"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy the sample application to your OpenShift cluster"
echo "2. Wait for metrics to start flowing to Datadog"
echo "3. Trigger the /simulate-load endpoint to exceed memory threshold"
echo "4. Check the dashboard and monitor for alerts"

# Made with Bob
