#!/bin/bash
# Functions for Fail2ban configuration

# Function to set up Fail2ban
setup_fail2ban() {    
    # Check if Fail2ban is installed
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_error "Fail2ban is not installed. Please install it first." 1
        exit 1
    fi
    
    # Create jail.local file
    local jail_config="/etc/fail2ban/jail.local"
    log_message "Creating Fail2ban configuration at $jail_config"
    
    # Backup existing config if it exists
    if [ -f "$jail_config" ]; then
        log_message "Backing up existing Fail2ban configuration"
        cp "$jail_config" "${jail_config}.bkp"
    fi
    
    # Create new configuration
    cat > "$jail_config" << EOF
[DEFAULT]
# Ban hosts for $F2B_BAN_TIME seconds
bantime = $F2B_BAN_TIME

# Find time window for $F2B_FIND_TIME seconds
findtime = $F2B_FIND_TIME

# Max retries before banning
maxretry = $F2B_MAX_RETRY

# Use iptables to ban hosts
banaction = iptables-multiport

# Enable SSH jail
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = $F2B_MAX_RETRY
EOF
    
    # Restart Fail2ban service
    log_message "Restarting Fail2ban service"
    systemctl restart fail2ban
    if [ $? -ne 0 ]; then
        log_error "Failed to restart Fail2ban service" 1
        exit 1
    fi
    
    # Wait for fail2ban to fully start
    log_message "Waiting for Fail2ban service to initialize..."
    sleep 3
    
    # Check Fail2ban status
    log_message "Checking Fail2ban status"
    fail2ban-client status
    
    log_success "Fail2ban setup completed"
}
