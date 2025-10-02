# GitHub Copilot Instructions for nuc-provision

## Project Overview
This is an Ansible-based automation project for provisioning Intel NUC devices running Windows. The project focuses on:
- Desktop application installation and configuration
- User account management and security policies
- System configuration (hostname, networking, monitoring)
- Automated housekeeping and updates
- Idempotent and reproducible deployments across multiple devices

## Code Style and Standards
- **Ansible YAML**: Use proper indentation (2 spaces), descriptive task names, and include `tags` for role organization
- **Variables**: Use environment variable lookups with sensible defaults: `"{{ lookup('env','VAR_NAME') | default('fallback') }}"`
- **Secrets**: Never hardcode passwords, API keys, or sensitive data. Always use environment variables or Ansible Vault
- **Documentation**: Keep README.md updated with all environment variables and configuration options

## Project Structure
```
nuc-provision/
├── site.yml              # Main playbook
├── inventory.yml          # Host configuration and variables
├── roles/                 # Ansible roles directory
│   ├── apps/             # Software installation
│   ├── users/            # User management
│   ├── hostname/         # System naming
│   ├── security/         # Security policies
│   ├── housekeeping/     # Maintenance tasks
│   ├── updates/          # System updates
│   └── monitoring/       # Prometheus monitoring
└── group_vars/           # Group-specific variables

## Key Technologies
- **Ansible**: Infrastructure automation and configuration management
- **WinRM**: Windows Remote Management for connectivity
- **PowerShell**: Windows system administration
- **Chocolatey**: Package management for Windows applications
- **Prometheus**: System monitoring and metrics collection

## Windows-Specific Considerations
- Use `win_` modules for Windows operations (win_user, win_chocolatey, win_regedit, etc.)
- Handle Windows paths with backslashes and proper escaping
- Configure WinRM HTTPS connectivity with proper firewall rules
- Use Windows service management for long-running processes
- Implement proper error handling for Windows-specific operations

## Security Best Practices
- All sensitive data must use environment variables or Ansible Vault
- Never commit passwords, tokens, or certificates to version control
- Use HTTPS for WinRM connections with certificate validation
- Implement proper firewall rules and network security
- Follow principle of least privilege for user accounts

## Monitoring and Maintenance
- Include prometheus exporters for system metrics
- Implement automated update mechanisms
- Configure proper logging and error reporting
- Ensure idempotent operations for repeated runs
- Plan for multi-device scalability

When suggesting code changes:
1. Ensure compatibility with Windows target systems
2. Use appropriate Ansible modules for Windows
3. Include proper error handling and validation
4. Follow existing project patterns and conventions
5. Document any new environment variables in README.md