# Ubuntu Server Hardening Script

A comprehensive shell script to automatically harden Ubuntu 24.04 servers with security best practices. Perfect for securing your VPS when first setting it up. Works great with [lnvps.net](https://lnvps.net/) VPS instances.

## Overview

This script automates security hardening for Ubuntu 24.04 servers by implementing multiple best practices:

- ✅ [user.sh](lib/user.sh) – Secure user management (new sudo user with SSH key authentication)
- ✅ [ssh.sh](lib/ssh.sh) – SSH hardening (custom port, disable root login, disable password authentication)
- ✅ [firewall.sh](lib/firewall.sh) – Firewall configuration (UFW with restrictive rules)
- ✅ [fail2ban.sh](lib/fail2ban.sh) – Fail2ban setup (protection against brute force attacks)
- ✅ [updates.sh](lib/updates.sh) – Automatic security updates
- ✅ [motd.sh](lib/motd.sh) – Customize MOTD (Message of the Day)

## Prerequisites

- Ubuntu 24.04 LTS server
- Root/sudo access
- SSH access

If using an [lnvps.net](https://lnvps.net/) VPS, you'll receive login credentials after purchasing your instance. Use these to log in initially before running this script.

## Quick Start

1. Connect to your new server via SSH:

   ```bash
   ssh ubuntu@your-server-ip
   ```

2. Download and run the hardening script:

   ```bash
   # Download the script
   git clone https://github.com/joel-st/ubuntu-hardening.git

   # Enter the directory
   cd ubuntu-hardening

   # Make the script executable
   chmod +x hardening.sh

   # Run the script
   sudo ./hardening.sh
   ```

3. Follow the interactive prompts to customize your security settings

4. After the script completes, you'll be asked to reboot. When the system restarts, the new security settings will be active.

### Custom Configuration

All default settings can be adjusted in the `config.json` file for both interactive and non-interactive mode. This makes it easy to customize the hardening process to your specific needs.

## Modes

### Default

```bash
sudo ./hardening.sh
```

This will apply all hardening measures using the default values in `config.json`.

### Interactive

```bash
sudo ./hardening.sh -i
```

This will use all hardening measures using the default values in `config.json` but will provide prompts to change settings on the fly.

## After Hardening

After the script completes:

1. The script and configuration are copied to your new admin user's home directory
2. Log in using your new admin user and SSH port:

   ```bash
   ssh -p <port> <user>@your-server-ip
   ```

## Troubleshooting

### Package Lock Issue

```bash
[PREREQUISITES] Checking base packages...
[PREREQUISITES] Package found: sudo
E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 1541 (apt-get)
E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it
```

**Solution:** This error occurs when another package manager process is running. Wait for the other process to finish (may be an automatic update).

### SSH Directory Issue

```bash
[SSH] Verifying SSH configuration
Missing privilege separation directory: /run/sshd
```

**Solution:** This occurs because the SSH service directory is missing. Create it and restart the SSH service:

```bash
sudo mkdir -p /run/sshd
sudo systemctl restart ssh
```

### User Deletion Warning

```bash
sudo userdel -r ubuntu
[sudo] password for anon: 
userdel: ubuntu mail spool (/var/mail/ubuntu) not found
```

**Solution:** This is just a warning, not an error. It indicates that while removing the user, the mail spool directory wasn't found, but the user was still successfully deleted. You can safely ignore this message.

## License

CC0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
