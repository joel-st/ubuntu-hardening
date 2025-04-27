#!/bin/bash

# Ubuntu Server Hardening Script
# Based on security best practices for Ubuntu 24.04 LTS

set -e

# Script directory
# Will be set interactively in the main function
# USER_NAME=false
# USER_PASSWORD=false
# SSH_KEY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
INTERACTIVE=false
LOG_FILE="${SCRIPT_DIR}/hardening-$(date +%Y%m%d%H%M).log"
BASE_PACKAGES="sudo ufw fail2ban jq openssh-server unattended-upgrades apt-listchanges"

# Source library files
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/prerequisites.sh"
source "${SCRIPT_DIR}/lib/user.sh"
source "${SCRIPT_DIR}/lib/ssh.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/fail2ban.sh"
source "${SCRIPT_DIR}/lib/updates.sh"
source "${SCRIPT_DIR}/lib/motd.sh"

# Validation functions
validate_username() {
    local username=$1
    # Check length (2-32 characters)
    if [[ ${#username} -lt 2 || ${#username} -gt 32 ]]; then
        echo "Username must be between 2 and 32 characters."
        return 1
    fi
    
    # Check characters (alphanumeric and underscore only)
    if ! [[ $username =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Username must contain only letters, numbers, and underscores."
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "User '$username' already exists. Please choose a different username."
        return 1
    fi
    
    return 0
}

validate_password() {
    local password=$1
    
    # Only check if password is empty
    if [[ -z "$password" ]]; then
        echo "Password cannot be empty."
        return 1
    fi
    
    return 0
}

validate_ssh_key() {
    local ssh_key=$1
    # Check for basic SSH public key format (starts with ssh-rsa, ssh-ed25519, etc.)
    if ! [[ $ssh_key =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\ [A-Za-z0-9+/]+[=]{0,3}(\ .*)?$ ]]; then
        echo "Invalid SSH public key format. Expected format: 'ssh-rsa AAAAB3N...'"
        return 1
    fi
    
    # Check key length (basic check - a key should be fairly long)
    if [[ ${#ssh_key} -lt 100 ]]; then
        echo "SSH key appears to be too short. Please provide a valid public key."
        return 1
    fi
    
    return 0
}

# Function to parse JSON config
parse_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_file "No config file found, using defaults" "CONFIG"
    fi
    
    # Parse configuration values with defaults
    
    # User management
    if [ ! -f "$CONFIG_FILE" ]; then
        USER_ADD_TO_SUDO=true
    else
        USER_ADD_TO_SUDO=$(jq -r '.user.add_to_sudo // true' "$CONFIG_FILE")
    fi
    
    # SSH settings
    if [ ! -f "$CONFIG_FILE" ]; then
        SSH_PORT=42069
        SSH_DISABLE_PASSWORD_AUTH=true
        SSH_DISABLE_ROOT_LOGIN=true
        SSH_PROTOCOL=2
        SSH_MAX_AUTH_TRIES=5
        SSH_LOGIN_GRACE_TIME=30
        SSH_ALLOW_X11_FORWARDING=false
        SSH_CLIENT_ALIVE_INTERVAL=300
        SSH_CLIENT_ALIVE_COUNT_MAX=2
    else
        SSH_PORT=$(jq -r '.ssh.port // 42069' "$CONFIG_FILE")
        SSH_DISABLE_PASSWORD_AUTH=$(jq -r '.ssh.disable_password_auth // true' "$CONFIG_FILE")
        SSH_DISABLE_ROOT_LOGIN=$(jq -r '.ssh.disable_root_login // true' "$CONFIG_FILE")
        SSH_PROTOCOL=$(jq -r '.ssh.protocol // 2' "$CONFIG_FILE")
        SSH_MAX_AUTH_TRIES=$(jq -r '.ssh.max_auth_tries // 5' "$CONFIG_FILE")
        SSH_LOGIN_GRACE_TIME=$(jq -r '.ssh.login_grace_time // 30' "$CONFIG_FILE")
        SSH_ALLOW_X11_FORWARDING=$(jq -r '.ssh.allow_x11_forwarding // false' "$CONFIG_FILE")
        SSH_CLIENT_ALIVE_INTERVAL=$(jq -r '.ssh.client_alive_interval // 300' "$CONFIG_FILE")
        SSH_CLIENT_ALIVE_COUNT_MAX=$(jq -r '.ssh.client_alive_count_max // 2' "$CONFIG_FILE")
    fi
    
    # Firewall settings
    if [ ! -f "$CONFIG_FILE" ]; then
        UFW_DEFAULT_POLICY_INCOMING="deny"
        UFW_DEFAULT_POLICY_OUTGOING="allow"
        UFW_ALLOW_SSH=true
        UFW_ALLOW_HTTP=false
        UFW_ALLOW_HTTPS=false
        UFW_ENABLE_FIREWALL=true
    else
        UFW_DEFAULT_POLICY_INCOMING=$(jq -r '.firewall.policy_incoming // "deny"' "$CONFIG_FILE")
        UFW_DEFAULT_POLICY_OUTGOING=$(jq -r '.firewall.policy_outgoing // "allow"' "$CONFIG_FILE")
        UFW_ALLOW_SSH=$(jq -r '.firewall.allow_ssh // true' "$CONFIG_FILE")
        UFW_ALLOW_HTTP=$(jq -r '.firewall.allow_http // false' "$CONFIG_FILE")
        UFW_ALLOW_HTTPS=$(jq -r '.firewall.allow_https // false' "$CONFIG_FILE")
        UFW_ENABLE_FIREWALL=$(jq -r '.firewall.enable_firewall // true' "$CONFIG_FILE")
    fi
    
    # Fail2ban settings
    if [ ! -f "$CONFIG_FILE" ]; then
        F2B_BAN_TIME=600
        F2B_FIND_TIME=600
        F2B_MAX_RETRY=5
    else
        F2B_BAN_TIME=$(jq -r '.fail2ban.ban_time // 600' "$CONFIG_FILE")
        F2B_FIND_TIME=$(jq -r '.fail2ban.find_time // 600' "$CONFIG_FILE")
        F2B_MAX_RETRY=$(jq -r '.fail2ban.max_retry // 5' "$CONFIG_FILE")
    fi
    
    # Updates settings
    if [ ! -f "$CONFIG_FILE" ]; then
        UPDATE_INSTALL_SECURITY=true
        UPDATE_INSTALL_UPDATES=false
        UPDATE_AUTO_REBOOT=false
        UPDATE_REBOOT_TIME="02:00"
    else
        UPDATE_INSTALL_SECURITY=$(jq -r '.updates.install_security // true' "$CONFIG_FILE")
        UPDATE_INSTALL_UPDATES=$(jq -r '.updates.install_updates // false' "$CONFIG_FILE")
        UPDATE_AUTO_REBOOT=$(jq -r '.updates.auto_reboot // false' "$CONFIG_FILE")
        UPDATE_REBOOT_TIME=$(jq -r '.updates.reboot_time // "02:00"' "$CONFIG_FILE")
    fi
    
    # MOTD settings
    if [ ! -f "$CONFIG_FILE" ]; then
        MOTD_DISABLE_DEFAULT_MOTD=true
        MOTD_DISABLE_LAST_LOGIN=true
        MOTD_ASCII_ART="    HEY THERE!"
    else
        MOTD_DISABLE_DEFAULT_MOTD=$(jq -r '.motd.disable_default_motd // true' "$CONFIG_FILE")
        MOTD_DISABLE_LAST_LOGIN=$(jq -r '.motd.disable_last_login // true' "$CONFIG_FILE")
        MOTD_ASCII_ART=$(jq -r '.motd.ascii_art // "    HEY THERE!"' "$CONFIG_FILE")
    fi
    
    # Prerequisites
    if [ ! -f "$CONFIG_FILE" ]; then
        PREREQUISITES_ADDITIONAL_PACKAGES=""
    else
        PREREQUISITES_ADDITIONAL_PACKAGES=$(jq -r '.prerequisites.additional_packages | join(" ")' "$CONFIG_FILE")
    fi

    export USER_ADD_TO_SUDO SSH_PORT SSH_DISABLE_PASSWORD_AUTH SSH_DISABLE_ROOT_LOGIN \
           SSH_PROTOCOL SSH_MAX_AUTH_TRIES SSH_LOGIN_GRACE_TIME SSH_ALLOW_X11_FORWARDING SSH_CLIENT_ALIVE_INTERVAL \
           SSH_CLIENT_ALIVE_COUNT_MAX UFW_DEFAULT_POLICY_INCOMING UFW_DEFAULT_POLICY_OUTGOING UFW_ALLOW_SSH UFW_ALLOW_HTTP \
           UFW_ALLOW_HTTPS UFW_ENABLE_FIREWALL F2B_BAN_TIME F2B_FIND_TIME F2B_MAX_RETRY UPDATE_INSTALL_SECURITY UPDATE_INSTALL_UPDATES \
           UPDATE_AUTO_REBOOT UPDATE_REBOOT_TIME MOTD_DISABLE_DEFAULT_MOTD MOTD_DISABLE_LAST_LOGIN MOTD_ASCII_ART REMOVE_DEFAULT_USERS \
           PREREQUISITES_ADDITIONAL_PACKAGES
}

# Function to prompt for interactive configuration
configure_interactively() {
    local module=$1
    
    case $module in
        config)
            echo "[🚨] This script creates a new sudo user."
            echo "[🚨] All existing regular users will be removed after hardening."
            echo "[🚨] The script lets you use weak passwords, feel free to use the following security considerations:"
            echo "[👌🏻] Passwords should be at least 8 characters long"
            echo "[👌🏻] Include uppercase and lowercase letters"
            echo "[👌🏻] Include numbers and special characters"
            echo "[👌🏻] Avoid common words or patterns"
            echo
            
            # Username validation loop
            while true; do
                read -p "Enter new sudo username: " USER_NAME
                if [ -z "$USER_NAME" ]; then
                    echo "Error: Username cannot be empty. Please try again."
                    continue
                fi
                
                if validate_username "$USER_NAME"; then
                    break
                fi
            done
            
            # Password validation loop
            while true; do
                read -s -p "Enter password for $USER_NAME: " USER_PASSWORD
                echo
                if [ -z "$USER_PASSWORD" ]; then
                    echo "Error: Password cannot be empty. Please try again."
                    continue
                fi
                
                if validate_password "$USER_PASSWORD"; then
                    # Confirm password
                    read -s -p "Confirm password for $USER_NAME: " PASSWORD_CONFIRM
                    echo
                    
                    if [ "$USER_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                        echo "Error: Passwords do not match. Please try again."
                        continue
                    fi
                    
                    break
                fi
            done
            
            # SSH key validation loop
            while true; do
                read -p "Enter SSH public key for $USER_NAME: " SSH_KEY
                if [ -z "$SSH_KEY" ]; then
                    echo "Error: SSH key cannot be empty. Please try again."
                    continue
                fi
                
                if validate_ssh_key "$SSH_KEY"; then
                    break
                fi
            done
            
            read -p "Do you want to set a new root password? (y/n): " SET_ROOT_PASSWORD
            if [[ "$SET_ROOT_PASSWORD" =~ ^[Yy]$ ]]; then
                while true; do
                    read -s -p "Enter new root password: " ROOT_PASSWORD
                    echo
                    
                    if [ -z "$ROOT_PASSWORD" ]; then
                        echo "Warning: Root password is empty, skipping root password change."
                        break
                    fi
                    
                    if validate_password "$ROOT_PASSWORD"; then
                        # Confirm password
                        read -s -p "Confirm new root password: " ROOT_PASSWORD_CONFIRM
                        echo
                        
                        if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
                            echo "Error: Passwords do not match. Please try again."
                            continue
                        fi
                        
                        export ROOT_PASSWORD
                        break
                    fi
                done
            fi
            ;;
        prerequisites)
            read -p "Enter additional packages (space separated) [$PREREQUISITES_ADDITIONAL_PACKAGES]: " new_packages
            if [ -n "$new_packages" ]; then
                PREREQUISITES_ADDITIONAL_PACKAGES=$new_packages
                log_file "PREREQUISITES_ADDITIONAL_PACKAGES: $PREREQUISITES_ADDITIONAL_PACKAGES" "UPDATE CONFIG"
            fi
            ;;
        user)            
            read -p "Add user to sudo group? (true/false) [$USER_ADD_TO_SUDO]: " new_sudo
            if [ -n "$new_sudo" ]; then
                USER_ADD_TO_SUDO=$new_sudo
                log_file "USER_ADD_TO_SUDO: $USER_ADD_TO_SUDO" "UPDATE CONFIG"
            fi
            ;;
        ssh)
            read -p "Enter new SSH port (0-65535) [$SSH_PORT]: " new_port
            if [ -n "$new_port" ]; then
                SSH_PORT=$new_port
                log_file "SSH_PORT: $SSH_PORT" "UPDATE CONFIG"
            fi  
            
            read -p "Disable password authentication? (true/false) [$SSH_DISABLE_PASSWORD_AUTH]: " new_disable_pwd
            if [ -n "$new_disable_pwd" ]; then
                SSH_DISABLE_PASSWORD_AUTH=$new_disable_pwd
                log_file "SSH_DISABLE_PASSWORD_AUTH: $SSH_DISABLE_PASSWORD_AUTH" "UPDATE CONFIG"
            fi
            
            read -p "Disable root login? (true/false) [$SSH_DISABLE_ROOT_LOGIN]: " new_disable_root
            if [ -n "$new_disable_root" ]; then
                SSH_DISABLE_ROOT_LOGIN=$new_disable_root
                log_file "SSH_DISABLE_ROOT_LOGIN: $SSH_DISABLE_ROOT_LOGIN" "UPDATE CONFIG"
            fi
            ;;
        firewall)
            read -p "Default policy for incoming traffic (deny/allow) [$UFW_DEFAULT_POLICY_INCOMING]: " new_policy_in
            if [ -n "$new_policy_in" ]; then
                UFW_DEFAULT_POLICY_INCOMING=$new_policy_in
                log_file "UFW_DEFAULT_POLICY_INCOMING: $UFW_DEFAULT_POLICY_INCOMING" "UPDATE CONFIG"
            fi
            
            read -p "Allow SSH? (true/false) [$UFW_ALLOW_SSH]: " new_allow_ssh
            if [ -n "$new_allow_ssh" ]; then
                UFW_ALLOW_SSH=$new_allow_ssh
                log_file "UFW_ALLOW_SSH: $UFW_ALLOW_SSH" "UPDATE CONFIG"
            fi
            
            read -p "Allow HTTP? (true/false) [$UFW_ALLOW_HTTP]: " new_allow_http
            if [ -n "$new_allow_http" ]; then
                UFW_ALLOW_HTTP=$new_allow_http
                log_file "UFW_ALLOW_HTTP: $UFW_ALLOW_HTTP" "UPDATE CONFIG"
            fi
            
            read -p "Allow HTTPS? (true/false) [$UFW_ALLOW_HTTPS]: " new_allow_https
            if [ -n "$new_allow_https" ]; then
                UFW_ALLOW_HTTPS=$new_allow_https
                log_file "UFW_ALLOW_HTTPS: $UFW_ALLOW_HTTPS" "UPDATE CONFIG"
            fi
            ;;
        fail2ban)
            read -p "Enter ban time in seconds [$F2B_BAN_TIME]: " new_ban_time
            if [ -n "$new_ban_time" ]; then
                F2B_BAN_TIME=$new_ban_time
                log_file "F2B_BAN_TIME: $F2B_BAN_TIME" "UPDATE CONFIG"
            fi
            
            read -p "Enter find time in seconds [$F2B_FIND_TIME]: " new_find_time
            if [ -n "$new_find_time" ]; then
                F2B_FIND_TIME=$new_find_time
                log_file "F2B_FIND_TIME: $F2B_FIND_TIME" "UPDATE CONFIG"
            fi  
            
            read -p "Enter max retry attempts [$F2B_MAX_RETRY]: " new_max_retry
            if [ -n "$new_max_retry" ]; then
                F2B_MAX_RETRY=$new_max_retry
            fi
            ;;
        updates)
            read -p "Install security updates? (true/false) [$UPDATE_INSTALL_SECURITY]: " new_security
            if [ -n "$new_security" ]; then
                UPDATE_INSTALL_SECURITY=$new_security
                log_file "UPDATE_INSTALL_SECURITY: $UPDATE_INSTALL_SECURITY" "UPDATE CONFIG"
            fi
            
            read -p "Install all updates? (true/false) [$UPDATE_INSTALL_UPDATES]: " new_updates
            if [ -n "$new_updates" ]; then
                UPDATE_INSTALL_UPDATES=$new_updates
                log_file "UPDATE_INSTALL_UPDATES: $UPDATE_INSTALL_UPDATES" "UPDATE CONFIG"
            fi
            
            read -p "Auto reboot after updates? (true/false) [$UPDATE_AUTO_REBOOT]: " new_reboot
            if [ -n "$new_reboot" ]; then
                UPDATE_AUTO_REBOOT=$new_reboot
                log_file "UPDATE_AUTO_REBOOT: $UPDATE_AUTO_REBOOT" "UPDATE CONFIG"
            fi
            ;;
        motd)
            read -p "Disable default MOTD? (true/false) [$MOTD_DISABLE_DEFAULT_MOTD]: " new_disable_motd
            if [ -n "$new_disable_motd" ]; then
                MOTD_DISABLE_DEFAULT_MOTD=$new_disable_motd
                log_file "MOTD_DISABLE_DEFAULT_MOTD: $MOTD_DISABLE_DEFAULT_MOTD" "UPDATE CONFIG"
            fi
            
            read -p "Disable last login message? (true/false) [$MOTD_DISABLE_LAST_LOGIN]: " new_disable_last
            if [ -n "$new_disable_last" ]; then
                MOTD_DISABLE_LAST_LOGIN=$new_disable_last
                log_file "MOTD_DISABLE_LAST_LOGIN: $MOTD_DISABLE_LAST_LOGIN" "UPDATE CONFIG"
            fi
            ;;
    esac
}

# Process command line arguments
process_args() {
    for arg in "$@"; do
        case $arg in
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            *)
                # Unknown option
                ;;
        esac
    done
}

# Main function
main() {
    # Process command line arguments
    process_args "$@"
    
    # Parse config
    parse_config
    
    # Initialize logging
    echo
    set_task "INITIALIZING"
    init_logging
    
    log_message "Starting server hardening process"
    
    # Run prerequisites check
    set_task "PREREQUISITES"

    # Prerequisites
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "prerequisites"
    fi
    echo
    log_message "Checking prerequisites"
    check_prerequisites

    # set sensitive information (username, password, ssh key) first
    echo
    configure_interactively "config"
    
    # User management
    set_task "USER"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "user"
    fi
    echo
    log_message "Configuring user"
    configure_user
    
    # SSH hardening
    set_task "SSH"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "ssh"
    fi
    echo
    log_message "Hardening SSH"
    harden_ssh
    
    # Firewall configuration
    set_task "FIREWALL"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "firewall"
    fi
    echo
    log_message "Configuring firewall"
    configure_firewall
    
    # Fail2ban installation and configuration
    set_task "FAIL2BAN"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "fail2ban"
    fi
    echo
    log_message "Setting up Fail2ban"
    setup_fail2ban
    
    # Automatic updates configuration
    set_task "UPDATES"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "updates"
    fi
    echo
    log_message "Configuring automatic updates"
    configure_updates
    
    # MOTD configuration
    set_task "MOTD"
    if [ "$INTERACTIVE" = "true" ]; then
        echo
        configure_interactively "motd"
    fi
    echo
    log_message "Setting up MOTD"
    configure_motd
    
    echo
    set_task "SUMMARY"
    log_success "Server hardening completed successfully"
    
    # Get server IP address for SSH connection example
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        # Fallback method if hostname -I doesn't work
        SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    fi
    
    # If we still don't have an IP, use placeholder
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="<server-ip>"
    fi
     
    # Copy hardening files to new user's home directory
    if [ -d "/home/$USER_NAME" ]; then
        echo
        log_message "Copying hardening files to new user's home directory"
        NEW_USER_DIR="/home/$USER_NAME/ubuntu-hardening"
        mkdir -p "$NEW_USER_DIR"
        cp -r "$SCRIPT_DIR"/* "$NEW_USER_DIR/"
        cp "$LOG_FILE" "$NEW_USER_DIR/"
        chown -R "$USER_NAME":"$USER_NAME" "$NEW_USER_DIR"
    else
        log_warning "New user home directory not found, skipping file copy" 1
    fi

    COLOR_GREEN="\033[0;32m"
    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"
    echo
    echo -e "${COLOR_BOLD}==========================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}Ubuntu Server Hardening completed!${COLOR_RESET}"
    echo -e "Log file: ${COLOR_GREEN}${COLOR_BOLD}$LOG_FILE${COLOR_RESET}"
    echo -e "${COLOR_BOLD}==========================================${COLOR_RESET}"
    echo
    echo -e "${COLOR_BOLD}${COLOR_GREEN}LOGIN INSTRUCTIONS:${COLOR_RESET}"
    echo -e "- SSH Port: ${COLOR_GREEN}${COLOR_BOLD}$SSH_PORT${COLOR_RESET}"
    echo -e "- Username: ${COLOR_GREEN}${COLOR_BOLD}$USER_NAME${COLOR_RESET}"
    echo -e "- Use your SSH key to authenticate"
    echo -e "- Command: ${COLOR_GREEN}${COLOR_BOLD}ssh -p $SSH_PORT $USER_NAME@$SERVER_IP${COLOR_RESET}"
    echo
    echo -e "${COLOR_BOLD}${COLOR_GREEN}IMPORTANT NOTES:${COLOR_RESET}"
    echo -e "- Your hardening files are copied to: ${COLOR_GREEN}${COLOR_BOLD}/home/$USER_NAME/ubuntu-hardening${COLOR_RESET}"
    echo -e "- Consider deleting default user: ${COLOR_GREEN}${COLOR_BOLD}sudo userdel -r ubuntu${COLOR_RESET}"

    echo
    echo "It is recommended to reboot the system to ensure all changes take effect."
    read -p "Would you like to reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "Scheduling reboot in 5 seconds"
        echo -e "Closing connection gracefully. Please reconnect after the reboot."
        # Schedule the shutdown with minimal output and exit immediately
        nohup bash -c "sleep 5 && shutdown -r now" >/dev/null 2>&1 &
        exit 0
    else
        echo "Please reboot at your earliest convenience."
    fi
}

# Run main function
main "$@"
