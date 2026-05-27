#!/bin/bash
# Cleanup script for Datadog Integration POC

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Datadog Integration POC - Cleanup Script              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will delete the following resources:${NC}"
echo "  - Namespace: datadog-poc (application)"
echo "  - Namespace: datadog (Datadog agent)"
echo "  - Datadog monitor and dashboard (manual cleanup required)"
echo ""

read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Cleaning up OpenShift resources${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Delete application namespace
if oc get namespace datadog-poc &>/dev/null; then
    echo "Deleting namespace: datadog-poc..."
    oc delete namespace datadog-poc
    echo -e "${GREEN}✓ Application namespace deleted${NC}"
else
    echo -e "${YELLOW}⚠ Namespace datadog-poc not found${NC}"
fi

# Ask about Datadog namespace
echo ""
read -p "Do you want to delete the Datadog agent namespace? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if oc get namespace datadog &>/dev/null; then
        echo "Deleting namespace: datadog..."
        oc delete namespace datadog
        echo -e "${GREEN}✓ Datadog namespace deleted${NC}"
    else
        echo -e "${YELLOW}⚠ Namespace datadog not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Keeping Datadog namespace${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Datadog Resources Cleanup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo ""
echo -e "${YELLOW}Manual cleanup required for Datadog resources:${NC}"
echo ""
echo "1. Delete Monitor:"
echo "   - Go to: https://app.datadoghq.com/monitors/manage"
echo "   - Search for: 'Memory Threshold Exceeded - POC Application'"
echo "   - Delete the monitor"
echo ""
echo "2. Delete Dashboard:"
echo "   - Go to: https://app.datadoghq.com/dashboard/lists"
echo "   - Search for: 'Memory Monitor POC - Datadog Integration'"
echo "   - Delete the dashboard"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Cleanup Completed Successfully!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Don't forget to manually delete the Datadog monitor and dashboard"
echo ""

# Made with Bob
