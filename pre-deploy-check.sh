#!/bin/bash
# Pre-deployment validation script
# Run this before deploying to verify everything is configured correctly

set -e

echo "🔍 Pre-Deployment Validation for nuc-provision"
echo "=============================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to check if a variable is set
check_env_var() {
    local var_name=$1
    local var_value=$(printenv "$var_name")
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}✗${NC} $var_name is not set"
        ((ERRORS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} $var_name is set"
        return 0
    fi
}

# Check required environment variables
echo -e "\n1. Checking Required Environment Variables..."
echo "--------------------------------------------"
check_env_var "WIN_USERNAME"
check_env_var "WIN_PASSWORD"
check_env_var "NUC1_ADDR"
check_env_var "TARGET_USERNAME"
check_env_var "TARGET_USER_PASSWORD"
check_env_var "PC_BASENAME"

# Check optional environment variables
echo -e "\n2. Checking Optional Environment Variables..."
echo "--------------------------------------------"
check_env_var "OBJC_DISABLE_INITIALIZE_FORK_SAFETY" || echo -e "${YELLOW}⚠${NC}  OBJC_DISABLE_INITIALIZE_FORK_SAFETY not set (needed on macOS)"
check_env_var "WIN_EXPORTER_VERSION" || echo -e "${YELLOW}⚠${NC}  WIN_EXPORTER_VERSION not set (will use default: 0.31.2)"
check_env_var "PRIMARY_DNS" || echo -e "${YELLOW}⚠${NC}  PRIMARY_DNS not set (will use default: 192.168.99.100)"
check_env_var "SECONDARY_DNS" || echo -e "${YELLOW}⚠${NC}  SECONDARY_DNS not set (will use default: 1.1.1.3)"

# Check network connectivity
echo -e "\n3. Checking Network Connectivity..."
echo "------------------------------------"
if [ -z "$NUC1_ADDR" ]; then
    echo -e "${RED}✗${NC} Cannot check connectivity - NUC1_ADDR not set"
    ((ERRORS++))
else
    echo "Testing connection to $NUC1_ADDR:5986..."
    if nc -z -w 5 "$NUC1_ADDR" 5986 2>/dev/null; then
        echo -e "${GREEN}✓${NC} WinRM port 5986 is accessible on $NUC1_ADDR"
    else
        echo -e "${RED}✗${NC} Cannot reach WinRM port 5986 on $NUC1_ADDR"
        echo -e "${YELLOW}⚠${NC}  Make sure you're on the same network as the NUC"
        echo -e "${YELLOW}⚠${NC}  Make sure WinRM is configured on the target machine"
        ((ERRORS++))
    fi
fi

# Check Ansible installation
echo -e "\n4. Checking Ansible Installation..."
echo "-----------------------------------"
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    echo -e "${GREEN}✓${NC} Ansible is installed: $ANSIBLE_VERSION"
else
    echo -e "${RED}✗${NC} Ansible is not installed"
    echo "   Install with: pip install ansible pywinrm"
    ((ERRORS++))
fi

# Check Python dependencies
echo -e "\n5. Checking Python Dependencies..."
echo "----------------------------------"
if python3 -c "import winrm" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} pywinrm is installed"
else
    echo -e "${RED}✗${NC} pywinrm is not installed"
    echo "   Install with: pip install pywinrm"
    ((ERRORS++))
fi

# Check Ansible collections
echo -e "\n6. Checking Ansible Collections..."
echo "----------------------------------"
if ansible-galaxy collection list | grep -q "ansible.windows"; then
    echo -e "${GREEN}✓${NC} ansible.windows collection is installed"
else
    echo -e "${RED}✗${NC} ansible.windows collection is not installed"
    echo "   Install with: ansible-galaxy collection install ansible.windows"
    ((ERRORS++))
fi

if ansible-galaxy collection list | grep -q "community.windows"; then
    echo -e "${GREEN}✓${NC} community.windows collection is installed"
else
    echo -e "${RED}✗${NC} community.windows collection is not installed"
    echo "   Install with: ansible-galaxy collection install community.windows"
    ((ERRORS++))
fi

if ansible-galaxy collection list | grep -q "chocolatey.chocolatey"; then
    echo -e "${GREEN}✓${NC} chocolatey.chocolatey collection is installed"
else
    echo -e "${RED}✗${NC} chocolatey.chocolatey collection is not installed"
    echo "   Install with: ansible-galaxy collection install chocolatey.chocolatey"
    ((ERRORS++))
fi

# Validate YAML syntax
echo -e "\n7. Validating Ansible Playbook Syntax..."
echo "----------------------------------------"
if ansible-playbook -i inventory.yml site.yml --syntax-check &>/dev/null; then
    echo -e "${GREEN}✓${NC} Playbook syntax is valid"
else
    echo -e "${RED}✗${NC} Playbook syntax has errors"
    ansible-playbook -i inventory.yml site.yml --syntax-check
    ((ERRORS++))
fi

# Check for secrets in git
echo -e "\n8. Checking for Committed Secrets..."
echo "-------------------------------------"
if git log --all --full-history -- local_config/ 2>/dev/null | grep -q "commit"; then
    echo -e "${RED}✗${NC} local_config/ files found in git history!"
    echo "   Secrets may have been committed. Consider using git-filter-repo to remove them."
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} No local_config/ files in git history"
fi

# Summary
echo -e "\n=========================================="
echo "Validation Summary"
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "\nYou can now run the playbook:"
    echo "  source local_config/chris.sh  # or keona.sh"
    echo "  ansible-playbook -i inventory.yml site.yml"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo -e "\nPlease fix the errors above before running the playbook."
    exit 1
fi
