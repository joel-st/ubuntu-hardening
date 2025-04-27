#!/bin/bash
# Functions for automatic updates configuration

# Function to configure automatic updates
configure_updates() {    
    # Check if unattended-upgrades is installed
    if ! command -v unattended-upgrade >/dev/null 2>&1; then
        log_error "unattended-upgrades is not installed. Please install it first." 1
        exit 1
    fi
    
    # Create configuration directories if they don't exist
    mkdir -p /etc/apt/apt.conf.d
    
    # Configure unattended-upgrades
    local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
    log_message "Creating unattended-upgrades configuration"
    
    # Backup existing config if it exists
    if [ -f "$config_file" ]; then
        log_message "Backing up existing unattended-upgrades configuration"
        cp "$config_file" "${config_file}.bkp"
    fi
    
    # Create new configuration
    cat > "$config_file" << EOF
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

// List of packages to not update (regexp are supported)
Unattended-Upgrade::Package-Blacklist {
    // "vim";
    // "libc6";
    // "libc6-dev";
    // "libc6-i686";
};

// This option allows you to control if on a unclean dpkg exit
// unattended-upgrades will automatically run 
// dpkg --force-confold --configure -a
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Split the upgrade into the smallest possible chunks so that
// they can be interrupted with SIGTERM. This makes the upgrade
// a bit slower but it has the benefit that shutdown while a upgrade
// is running is possible (with a small delay)
Unattended-Upgrade::MinimalSteps "true";

// Install all unattended-upgrades when the machine is shutting down
// instead of doing it in the background while the machine is running
// This will (obviously) make shutdown slower
Unattended-Upgrade::InstallOnShutdown "false";

// Send email to this address for problems or packages upgrades
// If empty or unset then no email is sent, make sure that you
// have a working mail setup on your system. A package that provides
// 'mailx' must be installed. E.g. "user@example.com"
Unattended-Upgrade::Mail "";

// Set this value to "true" to get emails only on errors. Default
// is to always send a mail if Unattended-Upgrade::Mail is set
Unattended-Upgrade::MailOnlyOnError "true";

// Remove unused automatically installed kernel-related packages
// (kernel images, kernel headers and kernel version locked tools).
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Do automatic removal of newly unused dependencies after the upgrade
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Do automatic removal of unused packages after the upgrade
// (equivalent to apt-get autoremove)
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot *WITHOUT CONFIRMATION* if
// the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "$UPDATE_AUTO_REBOOT";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
// Default: "now"
Unattended-Upgrade::Automatic-Reboot-Time "$UPDATE_REBOOT_TIME";
EOF
    
    # Configure APT periodic updates
    local apt_config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    log_message "Creating APT periodic updates configuration"
    
    # Determine update settings based on configuration
    local auto_updates="0"
    if [ "$UPDATE_INSTALL_UPDATES" = "true" ]; then
        auto_updates="1"
    fi
    
    local auto_security="0"
    if [ "$UPDATE_INSTALL_SECURITY" = "true" ]; then
        auto_security="1"
    fi
    
    # Create periodic updates configuration
    cat > "$apt_config_file" << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "$auto_security";
APT::Periodic::Enable "$auto_updates";
EOF
    
    # Configure apt-listchanges if installed
    if command -v apt-listchanges >/dev/null 2>&1; then
        log_message "Configuring apt-listchanges"
        
        local listchanges_config="/etc/apt/listchanges.conf"
        if [ -f "$listchanges_config" ]; then
            # Backup existing config
            cp "$listchanges_config" "${listchanges_config}.bkp"
            
            # Update configuration to show news and without prompting
            sed -i 's/^frontend=.*/frontend=text/' "$listchanges_config"
            sed -i 's/^email_address=.*/email_address=root/' "$listchanges_config"
            sed -i 's/^confirm=.*/confirm=0/' "$listchanges_config"
        fi
    fi
    
    # Enable and start unattended-upgrades service
    log_message "Enabling unattended-upgrades service"
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    
    # Verify configuration
    log_message "Testing unattended-upgrades configuration"
    unattended-upgrade --dry-run --debug
    
    log_success "Automatic updates configuration completed"
}