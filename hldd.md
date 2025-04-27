# High-Level Design Document: Server Hardening Script

## 1. Overview

This document details the design for a shell script that automates the hardening of an Ubuntu 24.04 server following security best practices. The script implements the security measures outlined in the HLDD, focusing on a fully interactive approach that delivers essential security improvements while allowing user customization at each step.

### 1.1. Script Structure

```tree
├── harden.sh (main script)
├── lib/
│   └── ...
├── LICENSE
└── README.md
```

## 2. Requirements

- Target OS: Ubuntu 24.04 LTS
- Execution privileges: Root or sudo access
- Shell: Bash
- Fully interactive & non interactive

## 3. User Interface

### 3.1 Fully interactive

The script is able to run in fully interactive mode, with no command-line options.

For each hardening step:

1. Display a summary explaining the purpose and security benefits
2. Present recommended default settings
3. Prompt user to either:
   - Apply the recommended settings (default option)
   - Enter custom settings
   - Skip this hardening step

### 3.2 Non interactive

The script can be run with flags for settings, uses default values if not specified.

## 4. Core Functions and Default Settings

```bash
# Function definitions with clear responsibilities
function check_prerequisites() {
    # Check for Ubuntu 24.04, root/sudo access, and required packages
    # Summary: Ensures the script runs on the correct OS version with proper permissions
}

function create_user() {
    # Create non-root user with sudo privileges
    # Generate strong password suggestion
    # Default: Username "anon" with sudo privileges
    # Summary: Running as root is dangerous; a dedicated admin user reduces risk of privilege escalation
}

function configure_ssh() {
    # Backup sshd_config (just create a copy in place with .bkp as suffix)
    # Configure SSH key authentication
    # Disable password authentication
    # Change SSH port
    # Restart SSH service
    # Default: Port 42069, key authentication only, no root login, Protocol 2 only
    # Summary: Prevents brute force attacks and unauthorized access by using keys instead of passwords and changing default ports to avoid automated scanning
}

function configure_firewall() {
    # Configure UFW default policies
    # Allow custom SSH port
    # Allow HTTP/HTTPS if needed
    # Enable UFW
    # Default: Deny incoming, allow outgoing, allow SSH on custom port
    # Summary: Restricts network access to only necessary services, blocking potential attack vectors
}

function install_fail2ban() {
    # Install and configure Fail2ban
    # Create custom jail for SSH
    # Default: 5 retries before 10-minute ban, monitor SSH regardless of port
    # Summary: Automatically blocks IP addresses with multiple failed login attempts preventing brute force attacks
}

function configure_motd() {
    # Setup Message of the Day with security information
    # Default: Distro, Virtual YES/NO, CPUs, RAM
    # Summary: Provides a slim message of the day
}

function configure_updates() {
    # Install and configure unattended-upgrades
    # Default: Auto-install security updates daily, notify admin of other updates
    # Summary: Ensures critical security patches are applied promptly, reducing vulnerability windows
}

function check_user_permissions() {
    # Verify only root has UID 0
    # Check for empty passwords
    # Lock unnecessary accounts
    # Default: Lock all system accounts not needed for operation
    # Summary: Prevents unauthorized access through unused or insecure accounts
}

function setup_deletion_script() {
    # Create a temporary script that runs at next startup to delete default user
    # Default: Removes the default ubuntu/admin user if a new admin user is created
    # Summary: Eliminates known default credentials that could be exploited
}

function log_changes() {
    # Record all changes made
    # Summary: Maintains an audit trail of security changes for future reference
}
```

## 5. Workflow

1. Display script banner and information
2. Check prerequisites
3. Execute hardening functions in sequence, each requiring user interaction:
   - Create non-root user
   - Configure SSH (with clear warnings about access changes)
   - Configure firewall
   - Install and configure Fail2ban
   - Setup MOTD message
   - Set up automatic updates
   - Check and fix user permissions
   - Setup next-boot cleanup script
4. Generate summary report
5. Request system restart with clear instructions for next login

## 6. Error Handling

- Each function returns a status code (0 for success, non-zero for failure)
- On error, the script logs the error and provides a human-readable message
- For critical errors, the script suggests resetting the VPS
- Trap SIGINT and SIGTERM to handle interruptions gracefully

## 7. Logging

- A `log_message` function to create a `hardening-yyyymmdd-hh.mm.log` in the root folder.

## 8. Security Considerations

- Script validates all inputs before execution
- Temporary files are created with secure permissions
- The script avoids storing sensitive data (like passwords) in plain text
- SSH key authentication is enforced before disabling password authentication
- A failsafe SSH session is established before applying changes
- System restart is required to complete the hardening process
- Clear instructions are provided for next login

## 9. System Restart and Cleanup

- After successful execution, the script:
  1. Creates a temporary startup script to remove the default user
  2. Displays login information for the newly created user
  3. Prompts the user to restart the system
  4. Provides clear instructions for post-restart login
