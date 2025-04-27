#!/bin/bash
# Functions for MOTD configuration

# Function to configure MOTD
configure_motd() {    
    # Create backup directory for MOTD files
    local backup_dir="/etc/update-motd.d.bak"
    mkdir -p "$backup_dir"
    
    # Disable default MOTD if specified
    if [ "$MOTD_DISABLE_DEFAULT_MOTD" = "true" ]; then
        log_message "Disabling default MOTD"
        
        # First, back up all default MOTD scripts
        if [ -d "/etc/update-motd.d" ]; then
            log_message "Backing up default MOTD scripts"
            cp -r /etc/update-motd.d/* "$backup_dir/" 2>/dev/null || true
            
            # Remove execute permissions from default scripts rather than deleting them
            # This approach is safer and easier to revert if needed
            log_message "Disabling execution of default MOTD scripts"
            chmod -x /etc/update-motd.d/* 2>/dev/null || true
        fi
        
        # Backup and empty legal notice file
        if [ -f "/etc/legal" ]; then
            log_message "Backing up and clearing legal notices"
            cp /etc/legal /etc/legal.bak
            echo "" > /etc/legal
        fi
    fi
    
    # Disable last login message if specified
    if [ "$MOTD_DISABLE_LAST_LOGIN" = "true" ]; then
        log_message "Disabling last login message"
        
        if [ -f "/etc/pam.d/sshd" ]; then
            sed -i 's/^\(session[ \t]*optional[ \t]*pam_lastlog.so\)/#\1/' /etc/pam.d/sshd
        fi
    fi
    
    # Create custom MOTD following the article's approach
    log_message "Creating custom MOTD in /etc/motd"
    
    # Create the custom MOTD directly in /etc/motd
    cat > /etc/motd << EOF
    
$MOTD_ASCII_ART

    Distro:  $(. /etc/os-release 2>/dev/null && echo "$NAME $VERSION_ID $VERSION_CODENAME" || echo "Unknown")
    Virtual: $(grep -q "^flags.*hypervisor" /proc/cpuinfo 2>/dev/null || [ -d "/proc/xen" ] || [ "$(systemd-detect-virt 2>/dev/null)" != "none" ] && echo "YES" || echo "NO") 
    CPUs:    $(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "N/A")
    RAM:     $(awk "BEGIN {printf \"%.1f\", $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")/1024/1024}")GB

EOF
    
    # Disable the sudo reminder message
    if [ -f "/etc/update-motd.d/00-header" ]; then
        log_message "Disabling header containing sudo reminder"
        chmod -x /etc/update-motd.d/00-header
    fi
    
    if [ -f "/etc/update-motd.d/10-help-text" ]; then
        log_message "Disabling help text"
        chmod -x /etc/update-motd.d/10-help-text
    fi
    
    # Specifically target the "sudo command" message
    log_message "Disabling sudo reminder message"
    
    # Clear dynamic MOTD
    if [ -f "/run/motd.dynamic" ]; then
        echo "" > /run/motd.dynamic
    fi
    
    # The sudo message specifically comes from /etc/update-motd.d/90-updates-available typically
    for file in "/etc/update-motd.d/90-updates-available" "/etc/update-motd.d/98-reboot-required"; do
        if [ -f "$file" ]; then
            chmod -x "$file"
        fi
    done
    
    # Modify the PAM configuration to prevent the sudo message
    if [ -f "/etc/pam.d/sshd" ]; then
        # Add 'noupdate' to the pam_motd.so line to prevent sudo messages
        if grep -q "pam_motd.so" "/etc/pam.d/sshd"; then
            sed -i '/pam_motd.so/ s/$/ noupdate/' "/etc/pam.d/sshd"
        fi
    fi
    
    # Create a sudoers file to disable the sudo message
    echo 'Defaults        lecture=never' > /etc/sudoers.d/privacy
    chmod 0440 /etc/sudoers.d/privacy
    
    # On Ubuntu systems, the sudo message may come from /usr/lib/sudo/sudo_reminder
    if [ -f "/usr/lib/sudo/sudo_reminder" ]; then
        chmod -x /usr/lib/sudo/sudo_reminder 2>/dev/null || true
    fi
    
    # Check if the message might be in /etc/issue
    if grep -q "run a command as administrator" /etc/issue 2>/dev/null; then
        sed -i '/run a command as administrator/d' /etc/issue
    fi
    
    # Also check if the message is in /etc/issue.net
    if grep -q "run a command as administrator" /etc/issue.net 2>/dev/null; then
        sed -i '/run a command as administrator/d' /etc/issue.net
    fi
    
    log_success "MOTD configuration completed"
}


