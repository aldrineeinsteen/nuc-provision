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
- **Maximum UAC Level**: Set to "Always Notify" - prevents silent privilege elevation even for admins
- **USB Protection**: Autorun/Autoplay completely disabled to prevent malware from USB drives
- **Software Restriction Policy (SRP)**: Prevents installation of unauthorized software
- **Bloatware removal**: Automatically removes unwanted pre-installed software
- **Gaming software blocking**: Prevents installation of Roblox, gaming platforms, etc.
- **Microsoft Store restrictions**: Blocks app installation for standard users
- **Firefox lockdown**: Prevents extension installation and modifications
- **PowerShell Hardening**: 
  - Script Block Logging enabled
  - Full transcription to C:\Windows\Logs\PowerShell
  - Module logging enabled
  - RemoteSigned execution policy
- **Comprehensive Auditing**: 
  - Process creation with command line logging
  - User account management monitoring
  - Policy change detection
  - Logon/Logoff tracking
  - Privilege use monitoring
- **Disabled Services**: Fax, Remote Registry, Windows Error Reporting
- **Password Policy**: Minimum 8 chars, 90-day expiry, lockout after 5 failures
- **Non-admin user accounts**: Standard user privileges for daily use
- **Family Safety policies**: Age-appropriate content filtering
- **SmartScreen protection**: Warns against malicious downloads
- **Secure software installation**: Only from trusted sources (Chocolatey)
- **Daily monitoring**: Automatic detection and removal of unauthorized software

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

# Remove bloatware and block unauthorized software
ansible-playbook -i inventory.yml site.yml --tags bloatware

# Lock down Firefox browser
ansible-playbook -i inventory.yml site.yml --tags firefox

# Set up parental controls
ansible-playbook -i inventory.yml site.yml --tags parental-controls
```

**Available roles:**
- `apps`: Install educational and productivity software
- `bloatware-removal`: Remove unwanted software and prevent unauthorized installations
- `users`: Create and configure user accounts
- `hostname`: Set computer name
- `security`: Apply security policies and restrictions
- `firefox-lockdown`: Lock down Firefox browser and remove all extensions
- `parental-controls`: Configure Pi-hole DNS, BitDefender monitoring, and time restrictions
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

### 🦊 Firefox Lockdown
Complete browser protection to prevent unauthorized modifications:
- **Extension installation blocked**: Users cannot add or install any Firefox extensions
- **All existing extensions removed**: Cleans out any previously installed add-ons
- **Developer tools disabled**: Prevents access to about:config and debugging tools
- **Add-ons page blocked**: about:addons is inaccessible
- **Enterprise policies enforced**: Locks down via Mozilla's enterprise policy framework

**What's locked:**
- ❌ Cannot install extensions/add-ons
- ❌ Cannot access about:config
- ❌ Cannot use developer tools
- ❌ Cannot access about:addons
- ❌ Cannot modify browser settings
- ✅ Can still browse websites normally
- ✅ Can use bookmarks and history
- ✅ Can save passwords

### 🚫 Bloatware & Unauthorized Software Protection
Comprehensive software restrictions:

**Automatically removed:**
- **Roblox Studio and Roblox Player** (all installations and shortcuts)
- **WhatsApp Desktop** (app, shortcuts, and all user data)
- **bloxd.io** (PWA app, browser extensions, and shortcuts)
- **Gaming browser extensions** (Chrome, Edge, Firefox)
- **Candy Crush and gaming apps**
- **Xbox gaming apps**
- **Unwanted pre-installed Windows Store apps**
- **Other bloatware and trial software**
- **All desktop and Start Menu shortcuts** for blocked apps and games

**Installation prevention:**
- Microsoft Store disabled for standard users
- Executable files blocked in Downloads folder
- Software Restriction Policy (SRP) prevents unauthorized installations
- Daily monitoring removes any newly installed unauthorized software

**Website blocking (via hosts file):**
- **Gaming sites**: bloxd.io, roblox.com, now.gg, krunker.io, poki.com, crazygames.com, miniclip.com, y8.com, friv.com, addictinggames.com
- **Social media**: WhatsApp Web, TikTok, Instagram, Facebook, Messenger, Snapchat
- Blocks are automatically maintained and restored if modified
- DNS cache flushed automatically after changes

**Monitoring:**
- Runs daily at noon to check for unauthorized software
- Verifies hosts file blocks are still in place
- Logs all actions to `C:\Windows\Logs\bloatware_monitor.log`
- Automatically removes detected unauthorized applications
- Re-adds any removed hosts file entries

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

## Advanced Security Features

### 🔐 User Account Control (UAC)
- **Maximum Level Enforced**: Set to "Always Notify"
- **Applies to ALL users**: Including local administrators
- **Secure Desktop**: Prompts appear on isolated desktop
- **No Silent Elevation**: Every privilege escalation requires explicit approval

### 🛡️ PowerShell Security
- **Script Block Logging**: All PowerShell script blocks are logged
- **Transcription**: Full session recording to `C:\Windows\Logs\PowerShell`
- **Module Logging**: Tracks all module usage
- **Execution Policy**: RemoteSigned (only signed scripts from internet)
- **Prevents malicious scripts** while allowing legitimate administration

### 📊 Comprehensive Auditing
All security-relevant events are logged to Windows Security Event Log (1GB size):

**Process Auditing:**
- Every executable launched is logged with full command line
- Process termination tracking
- Helps detect malware and unauthorized software

**Account Management:**
- User account creation/modification/deletion
- Security group changes
- Account lockout events

**Policy Changes:**
- Detects attempts to modify security policies
- Tracks authentication policy changes
- Monitors authorization policy modifications

**Access Tracking:**
- Successful and failed logon attempts
- Special logon (administrator) tracking
- Sensitive privilege use monitoring

**Log Files Located:**
- Security logs: `Event Viewer → Windows Logs → Security`
- PowerShell logs: `C:\Windows\Logs\PowerShell`
- Application logs: `Event Viewer → Windows Logs → Application`

### 🔒 USB and Removable Media Protection
- **Autorun Disabled**: Prevents automatic execution from USB drives
- **Autoplay Blocked**: No automatic media playing
- **All Drive Types**: Protection applies to USB, CD/DVD, network drives
- **Prevents** common malware infection vector

### ⚙️ Service Hardening
**Disabled Unnecessary Services:**
- **Fax Service**: Not needed for children's computers
- **Remote Registry**: Prevents remote registry manipulation
- **Windows Error Reporting**: Reduces attack surface

### 🔑 Password Policy
- **Minimum Length**: 8 characters
- **Maximum Age**: 90 days (forced rotation)
- **Lockout Threshold**: 5 failed attempts
- **Lockout Duration**: 30 minutes
- **Complexity**: Enforced by Windows policy

## Security Best Practices for Families

1. **Regular password rotation**: Change passwords every 90 days (enforced automatically)
2. **Two-factor authentication**: Enable where possible
3. **Regular updates**: Keep all software current (automated via Chocolatey)
4. **Monitoring**: Check security event logs regularly
5. **Review PowerShell logs**: Check `C:\Windows\Logs\PowerShell` for suspicious activity
6. **Education**: Teach children about online safety
7. **Audit logs**: Periodically review Event Viewer → Security logs

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

**Firefox Extensions Not Blocked:**
```powershell
# Verify Firefox policies are in place
Test-Path "C:\Program Files\Mozilla Firefox\distribution\policies.json"

# Check if extensions folder was removed
Get-ChildItem "C:\Users\*\AppData\Roaming\Mozilla\Firefox\Profiles\*\extensions" -ErrorAction SilentlyContinue
```

**Bloatware Reappears:**
```powershell
# Check monitoring logs
Get-Content "C:\Windows\Logs\bloatware_monitor.log" -Tail 50

# Manually trigger bloatware check
powershell -ExecutionPolicy Bypass -File C:\Windows\monitor_bloatware.ps1

# Check if task is running
Get-ScheduledTask -TaskName "MonitorBloatware" | Select-Object TaskName, State, LastRunTime
```

**Roblox Still Installing:**
```powershell
# Check if Microsoft Store is properly disabled
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "RemoveWindowsStore"

# Verify SRP blocking rules
Get-ChildItem "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\262144\Paths"
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
