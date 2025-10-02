# nuc-provision

Ansible-based provisioning for Intel NUC devices running Windows.  
This project automates the setup of us| WIN_EXPORTER_VERSION       | Override the windows exporter prometheus version               | 0.31.2                             | No       |
| MON_LISTEN_ADDR            | Monitoring IP (localhost/0.0.0.0)                              | 0.0.0.0                            | No       |
| MON_PORT                   | Monitoring port                                                | 9182                               | No       |
| PRIMARY_DNS                | Primary DNS server (your Pi-hole)                             | 192.168.99.100                     | No       |
| SECONDARY_DNS              | Secondary DNS server (backup)                                  | 1.1.1.3                            | No       |accounts, hostname, security policies, software installation, monitoring, and housekeeping tasks for children's computers.  
It is designed to be **idempotent and reproducible**, making it easy to configure multiple NUCs consistently and safely.

---

## 🚨 Security Notice

**CRITICAL**: The `local_config/` folder contains hardcoded credentials and should NEVER be committed to version control!

Please ensure:
- `local_config/*.sh` files are in `.gitignore`
- Use environment variables or Ansible Vault for sensitive data
- Rotate any passwords that may have been accidentally committed

---

## Features for Children's Computers

### 🛡️ Security & Safety
- **Software Restriction Policy (SRP)**: Prevents installation of unauthorized software
- **Non-admin user accounts**: Standard user privileges for daily use
- **Family Safety policies**: Age-appropriate content filtering
- **SmartScreen protection**: Warns against malicious downloads
- **Secure software installation**: Only from trusted sources (Chocolatey)

### 📱 Applications & Learning
- **Educational software**: Firefox, LibreOffice, Python, Java, VS Code
- **Creative tools**: Blender for 3D modeling and animation
- **Productivity**: Thunderbird email, 7-Zip file management
- **Programming environment**: Python and Java for learning to code

### 🔧 System Management
- **Automatic updates**: Weekly Chocolatey package updates
- **Scheduled reboots**: Weekly restart for system health (Sunday 3 AM)
- **Power management**: High performance, no sleep/hibernation
- **System monitoring**: Prometheus metrics for health tracking
- **Hostname management**: Personalized computer names

---

## Pre-requisites on the Windows NUC

Before running Ansible from your controller (Mac/Linux), ensure the target NUC is prepared:

1. **Enable WinRM service**
   ```powershell

   Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory
   Get-NetConnectionProfile |
     Where-Object { $_.NetworkCategory -eq 'Public' -and $_.IPv4Connectivity -ne 'Disconnected' } |
     ForEach-Object { Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private }
   
   winrm quickconfig -q
   Enable-PSRemoting -Force

   Set-Service WinRM -StartupType Automatic
   Restart-Service WinRM

   winrm enumerate winrm/config/listener
   ```

2. **Configure WinRM HTTPS listener**
   ```powershell
   $dns = $env:COMPUTERNAME
   $cert = New-SelfSignedCertificate -DnsName $dns -CertStoreLocation Cert:\LocalMachine\My
   $thumb = $cert.Thumbprint
   winrm delete winrm/config/Listener?Address=*+Transport=HTTPS 2>$null | Out-Null
   winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$dns`";CertificateThumbprint=`"$thumb`"}"
   ```

3. **Open firewall for WinRM**
   ```powershell
   New-NetFirewallRule -Name "Allow WinRM HTTPS" -DisplayName "Allow WinRM HTTPS" -Protocol TCP -LocalPort 5986 -Direction Inbound -Action Allow -RemoteAddress 192.168.100.0/24
   ```

4. **Set network profile**
   ```powershell
   Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
   ```

5. **Verify connectivity**
   ```powershell
   Test-WSMan -ComputerName localhost -UseSSL
   ```
   From your controller machine:
   ```bash
   nc -vz xxx.xxx.xxx.xxx 5986
   ```

---

## Setup on the Controller Machine

```bash
python3 -m venv .venv
source .venv/bin/activate   # Linux/macOS
# .venv\Scripts\Activate.ps1   # Windows PowerShell

pip install --upgrade pip
pip install ansible pywinrm requests-ntlm
pip install 'pywinrm[credssp]'    # Optional

ansible-galaxy collection install ansible.windows community.windows chocolatey.chocolatey
```

---

## Environment Variables

Set these before running Ansible. They are used for authentication, configuration, and monitoring:

| Variable                   | Purpose                                                        | Example Value                      | Required |
|----------------------------|----------------------------------------------------------------|------------------------------------|----------|
| WIN_USERNAME               | WinRM administrator account                                    | NUCBOX_M5PLUS\Administrator        | Yes      |
| WIN_PASSWORD               | Password for the above account                                 | (your password)                    | Yes      |
| NUC1_ADDR                  | Target NUC IP/DNS                                              | 192.168.100.139                    | Yes      |
| TARGET_USERNAME            | Local standard user to create                                  | chris                              | Yes      |
| TARGET_USER_PASSWORD       | Password for the local user                                    | (your password)                    | Yes      |
| PC_BASENAME                | Computer name (short hostname, no dots)                        | CHRIS-NUC                          | Yes      |
| OBJC_DISABLE_INITIALIZE_FORK_SAFETY | macOS fork-safety workaround                          | YES                                | macOS    |
| WIN_EXPORTER_VERSION       | Override the windows exporter prometheus version               | 0.31.2                             | No       |
| MON_LISTEN_ADDR            | Monitoring IP (localhost/0.0.0.0)                              | 0.0.0.0                            | No       |
| MON_PORT                   | Monitoring port                                                | 9182                               | No       |

**How to set:**
```bash
export WIN_USERNAME='<admin-username>'
export WIN_PASSWORD='<admin-password>'
export NUC1_ADDR='<nuc-ip-or-dns>'
export TARGET_USERNAME='<username>'
export TARGET_USER_PASSWORD='<target-user-password>'
export PC_BASENAME='<pc-name>'
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export WIN_EXPORTER_VERSION=0.31.2
export MON_LISTEN_ADDR=0.0.0.0
export MON_PORT=9182
export PRIMARY_DNS=192.168.99.100
export SECONDARY_DNS=1.1.1.3
```

> **Security Note:** Never commit secrets (passwords, tokens) to version control. Use environment variables or Ansible Vault for sensitive data.

---

## Running Playbooks

**Full provisioning:**
```bash
ansible-playbook -i inventory.yml site.yml
```

**Dry-run mode (check what would change):**
```bash
ansible-playbook -i inventory.yml site.yml --check
```

**Run specific roles only:**
```bash
# Install applications only
ansible-playbook -i inventory.yml site.yml --tags apps

# Update security settings only
ansible-playbook -i inventory.yml site.yml --tags security

# Set up user accounts only
ansible-playbook -i inventory.yml site.yml --tags users

# Configure hostname only
ansible-playbook -i inventory.yml site.yml --tags hostname

# Set up housekeeping tasks only
ansible-playbook -i inventory.yml site.yml --tags housekeeping

# Install system updates only
ansible-playbook -i inventory.yml site.yml --tags updates
```

**Available roles:**
- `apps`: Install educational and productivity software
- `users`: Create and configure user accounts
- `hostname`: Set computer name
- `security`: Apply security policies and restrictions
- `housekeeping`: Configure automated maintenance
- `updates`: Install Windows updates
- `monitoring`: Set up Prometheus monitoring (commented out by default)

## Installed Applications

The following applications are automatically installed via Chocolatey:

| Application | Purpose | Child-Friendly |
|-------------|---------|----------------|
| Firefox | Web browser with parental controls | ✅ |
| Thunderbird | Email client | ✅ |
| VS Code | Code editor for learning programming | ✅ |
| Python | Programming language | ✅ |
| Java (Temurin 17) | Programming language (LTS version) | ✅ |
| 7-Zip | File compression utility | ✅ |
| Blender | 3D modeling and animation | ✅ |
| LibreOffice | Office suite (Word, Excel alternative) | ✅ |

---

## Network & Security Integration

### 🏠 Pi-hole Integration
Your existing Pi-hole at `192.168.99.100` provides:
- **Ad blocking**: Removes ads and trackers automatically
- **Family-safe filtering**: Configure additional block lists for inappropriate content
- **Custom blocking**: Add specific domains to block as needed
- **Network-wide protection**: All devices benefit from filtering

**Pi-hole Configuration Tips:**
```bash
# Add family-friendly block lists to your Pi-hole:
# - https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts
# - https://someonewhocares.org/hosts/zero/hosts
# - https://raw.githubusercontent.com/hectorm/hmirror/master/data/adguard-dns/list.txt
```

### 🛡️ BitDefender Parental Control
The playbook automatically:
- **Monitors BitDefender services** every 30 minutes
- **Re-enables parental control** if it gets disabled
- **Logs all actions** to `C:\Windows\Logs\bitdefender_monitor.log`
- **Notifies users** when parental control is restored

**Manual BitDefender Management:**
```powershell
# Check BitDefender status
Get-Service BDAuxSrv, BDVEDISK, vsserv

# Manually re-enable if needed (run as admin)
Start-Service BDAuxSrv
```

## Additional Features for Children's Safety & Education

### 🚀 Recommended Enhancements

Consider implementing these additional features for better child safety and educational value:

#### Educational Applications
- **Scratch**: Visual programming for kids (`choco install scratch`)
- **Krita**: Digital painting and art creation (`choco install krita`)
- **OBS Studio**: Screen recording for creating tutorials (`choco install obs-studio`)
- **Audacity**: Audio editing for podcasts/music (`choco install audacity`)
- **GIMP**: Image editing software (`choco install gimp`)

#### Safety & Monitoring
- **Pi-hole DNS Filtering**: Leverages your existing Pi-hole at 192.168.99.100 for ad-blocking and family-safe filtering
- **BitDefender Integration**: Automatically monitors and re-enables BitDefender Parental Control if it gets disabled
- **Time Restrictions**: Implement daily computer usage limits with bedtime shutdowns
- **Application Whitelisting**: More granular SRP rules for specific applications
- **Screen Time Monitoring**: Log application usage statistics
- **Activity Monitoring**: BitDefender parental control status monitoring every 30 minutes

#### Parental Controls
```yaml
# Example additions to security role:
- name: Configure OpenDNS for families
  ansible.windows.win_shell: |
    netsh interface ip set dns "Wi-Fi" static 208.67.222.123 primary
    netsh interface ip add dns "Wi-Fi" 208.67.220.123 index=2

- name: Set daily usage time limits
  community.windows.win_scheduled_task:
    name: DailyShutdown
    description: "Enforce bedtime shutdown"
    actions:
      - path: C:\Windows\System32\shutdown.exe
        arguments: "/s /t 300 /c 'Computer will shut down in 5 minutes for bedtime'"
    triggers:
      - type: daily
        start_boundary: "2025-01-01T20:00:00"  # 8 PM shutdown
```

#### Educational Content
- **Offline Wikipedia**: Download educational content for offline access
- **Programming Tutorials**: Pre-install Python learning resources
- **Math Software**: Install GeoGebra for mathematics (`choco install geogebra`)

### 🔧 System Improvements

#### Performance & Maintenance
```bash
# Add to housekeeping role:
ansible-playbook -i inventory.yml site.yml --tags housekeeping --extra-vars "enable_disk_cleanup=true"
```

#### Backup Configuration
- **Automated backups**: Schedule regular backups of user documents
- **Cloud sync**: Configure OneDrive or similar for document safety
- **System restore points**: Create weekly system restore points

## Security Best Practices for Families

1. **Regular password rotation**: Change passwords every 90 days
2. **Two-factor authentication**: Enable where possible
3. **Regular updates**: Keep all software current (automated via Chocolatey)
4. **Monitoring**: Check system logs and activity regularly
5. **Education**: Teach children about online safety

## Troubleshooting

### Common Issues

**WinRM Connection Problems:**
```bash
# Test connectivity
ansible nucs -i inventory.yml -m win_ping
```

**Application Installation Failures:**
```bash
# Check Chocolatey status
ansible nucs -i inventory.yml -m ansible.windows.win_shell -a "choco list --local-only"
```

**Security Policy Conflicts:**
```bash
# Check SRP status
ansible nucs -i inventory.yml -m ansible.windows.win_shell -a "gpresult /r"
```

## Contributing

Contributions are welcome! 🎉  
If you have ideas, improvements, or find issues, please:

1. Open an issue describing the bug or feature request.
2. Fork the repo and create a feature branch.
3. Submit a pull request with clear commit messages.

Suggestions for improvements to roles, tasks, or documentation are highly encouraged.

### Ideas for Contributions
- Additional educational software packages
- Enhanced parental control features
- Improved monitoring and reporting
- Multi-language support for international families
- Integration with popular family safety services

---

## License

This project is open-source under the [Apache 2.0](LICENSE).
