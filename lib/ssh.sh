#!/bin/bash
# Functions for SSH configuration

# Function to perform SSH hardening
harden_ssh() {
    local ssh_config="/etc/ssh/sshd_config"
    local backup_file="${ssh_config}.bkp"
    
    # Check if SSH config exists
    if [ ! -f "$ssh_config" ]; then
        log_error "SSH config file not found: $ssh_config" 1
        exit 1
    fi
    
    # Backup original config
    log_message "Backing up SSH config"
    cp "$ssh_config" "$backup_file"
    if [ $? -ne 0 ]; then
        log_error "Failed to backup SSH config" 1
        exit 1
    fi
    
    # Change SSH port
    log_message "Setting SSH port to $SSH_PORT"
    sed -i "s/^#*Port .*/Port $SSH_PORT/" "$ssh_config"
    if grep -q "^Port" "$ssh_config"; then
        :  # Port already set
    else
        echo "Port $SSH_PORT" >> "$ssh_config"
    fi
    
    # Disable root login if specified
    if [ "$SSH_DISABLE_ROOT_LOGIN" = "true" ]; then
        log_message "Disabling root login"
        sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" "$ssh_config"
        if grep -q "^PermitRootLogin" "$ssh_config"; then
            :  # PermitRootLogin already set
        else
            echo "PermitRootLogin no" >> "$ssh_config"
        fi
    fi
    
    # Disable password authentication if specified
    if [ "$SSH_DISABLE_PASSWORD_AUTH" = "true" ]; then
        log_message "Disabling password authentication"
        sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$ssh_config"
        if grep -q "^PasswordAuthentication" "$ssh_config"; then
            :  # PasswordAuthentication already set
        else
            echo "PasswordAuthentication no" >> "$ssh_config"
        fi
    fi
    
    # Restrict SSH access to only the new user
    log_message "Restricting SSH access to user: $USER_NAME"
    sed -i "s/^#*AllowUsers .*/AllowUsers $USER_NAME/" "$ssh_config"
    if grep -q "^AllowUsers" "$ssh_config"; then
        :  # AllowUsers already set
    else
        echo "AllowUsers $USER_NAME" >> "$ssh_config"
    fi
    
    # Set protocol version
    log_message "Setting SSH protocol version to $SSH_PROTOCOL"
    sed -i "s/^#*Protocol .*/Protocol $SSH_PROTOCOL/" "$ssh_config"
    if grep -q "^Protocol" "$ssh_config"; then
        :  # Protocol already set
    else
        echo "Protocol $SSH_PROTOCOL" >> "$ssh_config"
    fi
    
    # Set max auth tries
    log_message "Setting max authentication tries to $SSH_MAX_AUTH_TRIES"
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries $SSH_MAX_AUTH_TRIES/" "$ssh_config"
    if grep -q "^MaxAuthTries" "$ssh_config"; then
        :  # MaxAuthTries already set
    else
        echo "MaxAuthTries $SSH_MAX_AUTH_TRIES" >> "$ssh_config"
    fi
    
    # Set login grace time
    log_message "Setting login grace time to $SSH_LOGIN_GRACE_TIME"
    sed -i "s/^#*LoginGraceTime .*/LoginGraceTime $SSH_LOGIN_GRACE_TIME/" "$ssh_config"
    if grep -q "^LoginGraceTime" "$ssh_config"; then
        :  # LoginGraceTime already set
    else
        echo "LoginGraceTime $SSH_LOGIN_GRACE_TIME" >> "$ssh_config"
    fi
    
    # Configure X11 forwarding
    local x11_value="no"
    if [ "$SSH_ALLOW_X11_FORWARDING" = "true" ]; then
        x11_value="yes"
    fi
    log_message "Setting X11 forwarding to $x11_value"
    sed -i "s/^#*X11Forwarding .*/X11Forwarding $x11_value/" "$ssh_config"
    if grep -q "^X11Forwarding" "$ssh_config"; then
        :  # X11Forwarding already set
    else
        echo "X11Forwarding $x11_value" >> "$ssh_config"
    fi
    
    # Set client alive interval and count
    log_message "Setting client alive interval to $SSH_CLIENT_ALIVE_INTERVAL"
    sed -i "s/^#*ClientAliveInterval .*/ClientAliveInterval $SSH_CLIENT_ALIVE_INTERVAL/" "$ssh_config"
    if grep -q "^ClientAliveInterval" "$ssh_config"; then
        :  # ClientAliveInterval already set
    else
        echo "ClientAliveInterval $SSH_CLIENT_ALIVE_INTERVAL" >> "$ssh_config"
    fi
    
    log_message "Setting client alive count max to $SSH_CLIENT_ALIVE_COUNT_MAX"
    sed -i "s/^#*ClientAliveCountMax .*/ClientAliveCountMax $SSH_CLIENT_ALIVE_COUNT_MAX/" "$ssh_config"
    if grep -q "^ClientAliveCountMax" "$ssh_config"; then
        :  # ClientAliveCountMax already set
    else
        echo "ClientAliveCountMax $SSH_CLIENT_ALIVE_COUNT_MAX" >> "$ssh_config"
    fi
    
    # Verify the configuration
    log_message "Verifying SSH configuration"
    sshd -t
    if [ $? -ne 0 ]; then
        log_error "SSH configuration is invalid. Restoring backup..." 1
        cp "$backup_file" "$ssh_config"
        log_error "SSH hardening failed - configuration was invalid" 1
        exit 1
    fi
    
    # Restart SSH service
    log_message "Restarting SSH service"
    systemctl restart ssh
    if [ $? -ne 0 ]; then
        log_error "Failed to restart SSH service" 1
        exit 1
    fi
    
    log_success "SSH hardening completed successfully"
}