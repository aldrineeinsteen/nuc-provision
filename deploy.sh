#!/bin/bash
# Deployment Script for NUC Provisioning
# This script provides a safe way to deploy configurations

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [chris|keona] [--check|--deploy]"
    echo ""
    echo "Options:"
    echo "  chris|keona    Choose which NUC to provision"
    echo "  --check        Run in check mode (dry run, no changes)"
    echo "  --deploy       Actually deploy the configuration"
    echo ""
    echo "Examples:"
    echo "  $0 chris --check     # Test Chris's NUC deployment"
    echo "  $0 keona --deploy    # Actually deploy to Keona's NUC"
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

TARGET=$1
MODE=$2

# Validate target
if [ "$TARGET" != "chris" ] && [ "$TARGET" != "keona" ]; then
    echo -e "${RED}Error: Target must be 'chris' or 'keona'${NC}"
    usage
fi

# Validate mode
if [ "$MODE" != "--check" ] && [ "$MODE" != "--deploy" ]; then
    echo -e "${RED}Error: Mode must be '--check' or '--deploy'${NC}"
    usage
fi

# Source configuration
CONFIG_FILE="local_config/${TARGET}.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}NUC Provisioning Deployment Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Target: ${GREEN}$TARGET${NC}"
echo -e "Mode: ${YELLOW}$([ "$MODE" == "--check" ] && echo "DRY RUN" || echo "LIVE DEPLOYMENT")${NC}"
echo ""

# Source the configuration
echo "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

# Run pre-deployment checks
echo -e "\n${BLUE}Running pre-deployment checks...${NC}"
if ! ./pre-deploy-check.sh; then
    echo -e "\n${RED}Pre-deployment checks failed!${NC}"
    echo "Please fix the issues above before deploying."
    exit 1
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook -i inventory.yml site.yml"

if [ "$MODE" == "--check" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --check --diff"
    echo -e "\n${YELLOW}Running in CHECK mode (no actual changes will be made)${NC}"
else
    echo -e "\n${RED}WARNING: This will make LIVE CHANGES to the target NUC!${NC}"
    echo -e "Target NUC: $NUC1_ADDR"
    echo -e "Target User: $TARGET_USERNAME"
    echo -e "PC Name: $PC_BASENAME"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Run ansible playbook
echo -e "\n${BLUE}Starting Ansible playbook...${NC}"
echo "Command: $ANSIBLE_CMD"
echo ""

$ANSIBLE_CMD

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}================================================${NC}"
    
    if [ "$MODE" == "--deploy" ]; then
        echo -e "\n${BLUE}Post-deployment notes:${NC}"
        echo "• Check BitDefender monitoring: C:\\Windows\\Logs\\bitdefender_monitor.log"
        echo "• Check bloatware monitoring: C:\\Windows\\Logs\\bloatware_monitor.log"
        echo "• Verify Firefox policies: C:\\Program Files\\Mozilla Firefox\\distribution\\policies.json"
        echo "• Test user account: Log in as '$TARGET_USERNAME'"
        echo "• Verify DNS: Should be using Pi-hole at $PRIMARY_DNS"
    fi
else
    echo -e "\n${RED}================================================${NC}"
    echo -e "${RED}Deployment failed!${NC}"
    echo -e "${RED}================================================${NC}"
    echo "Check the error messages above for details."
    exit 1
fi
