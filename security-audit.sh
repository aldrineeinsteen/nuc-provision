#!/bin/bash
# Security Audit Script for nuc-provision
# Run this script to check for potential security issues

echo "🔒 Security Audit for nuc-provision"
echo "=================================="

# Check for hardcoded secrets in files
echo -e "\n1. Checking for hardcoded secrets..."
if git grep -i "password\s*=\s*['\"][^{]" -- '*.yml' '*.yaml' '*.sh' 2>/dev/null; then
    echo "❌ Found potential hardcoded passwords!"
else
    echo "✅ No hardcoded passwords found in tracked files"
fi

# Check if local_config is properly ignored
echo -e "\n2. Checking .gitignore configuration..."
if grep -q "local_config" .gitignore; then
    echo "✅ local_config directory is properly ignored"
else
    echo "❌ local_config directory is NOT in .gitignore"
fi

# Check if local_config files exist
echo -e "\n3. Checking for local configuration files..."
if ls local_config/*.sh 2>/dev/null; then
    echo "⚠️  Local config files found - ensure they contain no real passwords before committing!"
else
    echo "✅ No local config files found"
fi

# Check environment variables are being used
echo -e "\n4. Checking environment variable usage..."
if grep -q "lookup('env'" inventory.yml; then
    echo "✅ Environment variables are properly used in inventory.yml"
else
    echo "❌ inventory.yml may contain hardcoded values"
fi

# Check for default passwords
echo -e "\n5. Checking for default/weak passwords..."
if grep -i "admin\|password123\|123456" . -r --include="*.yml" --include="*.yaml" 2>/dev/null; then
    echo "❌ Found potential default passwords!"
else
    echo "✅ No obvious default passwords found"
fi

echo -e "\n📋 Security Recommendations:"
echo "• Use strong, unique passwords for all accounts"
echo "• Enable two-factor authentication where possible"
echo "• Regularly rotate passwords (every 90 days)"
echo "• Use Ansible Vault for storing secrets in production"
echo "• Monitor system logs for unauthorized access attempts"
echo "• Keep all software updated via automated updates"

echo -e "\n🎯 For Production Use:"
echo "• Consider using Ansible Vault: ansible-vault create secrets.yml"
echo "• Use certificate-based authentication instead of passwords"
echo "• Implement proper network segmentation"
echo "• Set up centralized logging and monitoring"