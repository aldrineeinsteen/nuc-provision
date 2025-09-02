# nuc-provision

Ansible-based provisioning for Intel NUC devices running Windows.  
This project automates the setup of user accounts, hostname, security policies, software installation, monitoring, and housekeeping tasks.  
It is designed to be **idempotent and reproducible**, making it easy to configure multiple NUCs (e.g., for family members) in a consistent way.

---

## Features

- Installs and configures essential desktop applications (Firefox, Thunderbird, VS Code, Python, Java, 7-Zip, Blender, LibreOffice).
- Enforces security settings (SmartScreen, restricted software installation, Family Safety).
- Manages users (e.g., creates a standard non-admin user).
- Sets hostname and static IP/DNS configuration.
- Enables monitoring endpoints for CPU/storage usage.
- Configures scheduled weekly reboots.
- Ensures the NUC never sleeps or hibernates.
- Designed to scale across multiple devices.

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

Configure these before running Ansible:

```bash
export WIN_USERNAME='<admin-username>'              # e.g. NUCBOX_M5PLUS\Administrator
export WIN_PASSWORD='<admin-password>'
export NUC1_ADDR='<nuc-ip-or-dns>'                  # e.g. 192.168.100.139
export TARGET_USERNAME='<username>'                      # standard user to create
export TARGET_USER_PASSWORD='<target-user-password>'
export PC_BASENAME='<pc-name>'                      # hostname (no dots)
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES      # macOS fork-safety workaround
export WIN_EXPORTER_VERSION=0.31.2      # to override the windows exporter version
export MON_LISTEN_ADDR=0.0.0.0     # Monitoring IP (localhost/0.0.0.0)
export MON_PORT=9182     # Monitoring port
```

**Reference:**

| Variable | Purpose |
|----------|---------|
| `WIN_USERNAME` | WinRM administrator account |
| `WIN_PASSWORD` | Password for the above account |
| `NUC1_ADDR` | Target NUC IP/DNS |
| `TARGET_USERNAME` | Local standard user to create |
| `TARGET_USER_PASSWORD` | Password for the local user |
| `PC_BASENAME` | Computer name (short hostname) |
| `OBJC_DISABLE_INITIALIZE_FORK_SAFETY` | Workaround for macOS fork-safety |
| `WIN_EXPORTER_VERSION` | Override the windows exporter prometheus version |

---

## Running Playbooks

```bash
ansible-playbook -i inventory.yml site.yml
```

Dry-run mode:

```bash
ansible-playbook -i inventory.yml site.yml --check
```

---

## Contributing

Contributions are welcome! 🎉  
If you have ideas, improvements, or find issues, please:

1. Open an issue describing the bug or feature request.
2. Fork the repo and create a feature branch.
3. Submit a pull request with clear commit messages.

Suggestions for improvements to roles, tasks, or documentation are highly encouraged.

---

## License

This project is open-source under the [Apache 2.0](LICENSE).
