#!/bin/bash
# Functions for firewall configuration

# Function to configure the firewall (UFW)
configure_firewall() {    
    # Check if UFW is installed
    if ! command -v ufw >/dev/null 2>&1; then
        log_error "UFW is not installed. Please install it first." 1
        exit 1
    fi
    
    # Reset UFW to default state
    log_message "Resetting UFW to default state"
    ufw --force reset
    
    # Set default policies
    log_message "Setting default policy for incoming traffic: $UFW_DEFAULT_POLICY_INCOMING"
    ufw default "$UFW_DEFAULT_POLICY_INCOMING" incoming
    
    log_message "Setting default policy for outgoing traffic: $UFW_DEFAULT_POLICY_OUTGOING"
    ufw default "$UFW_DEFAULT_POLICY_OUTGOING" outgoing
    
    # Allow SSH on custom port if enabled
    if [ "$UFW_ALLOW_SSH" = "true" ]; then
        log_message "Allowing SSH on port $SSH_PORT"
        ufw allow "$SSH_PORT/tcp" comment "SSH"
    else
        log_warning "SSH access through firewall has been disabled. This may lock you out of the system!" 1
    fi
    
    # Allow HTTP if enabled
    if [ "$UFW_ALLOW_HTTP" = "true" ]; then
        log_message "Allowing HTTP (port 80)"
        ufw allow 80/tcp comment "HTTP"
    fi
    
    # Allow HTTPS if enabled
    if [ "$UFW_ALLOW_HTTPS" = "true" ]; then
        log_message "Allowing HTTPS (port 443)"
        ufw allow 443/tcp comment "HTTPS"
    fi
    
    # Enable UFW if specified
    if [ "$UFW_ENABLE_FIREWALL" = "true" ]; then
        log_message "Enabling UFW"
        
        # Enable UFW with the --force option to avoid interactive prompt
        if ufw --force enable; then
            log_message "UFW enabled successfully"
        else
            log_error "Failed to enable UFW" 1
            exit 1
        fi
        
        # Check UFW status
        log_message "UFW Status:"
        ufw status verbose
    else
        log_warning "Firewall configuration completed but not enabled" 1
    fi
    
    log_success "Firewall configuration completed"
}