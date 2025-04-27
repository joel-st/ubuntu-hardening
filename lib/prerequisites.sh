#!/bin/bash
# Functions for checking prerequisites

# Check for Ubuntu 24.04, root/sudo access, and required packages
check_prerequisites() {    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root or with sudo privileges" 1
        exit 1
    fi
    log_success "Running with root privileges: OK"
    
    # Check Ubuntu version (warn)
    if [ -f /etc/lsb-release ]; then
        source /etc/lsb-release
        if [[ "$DISTRIB_ID" != "Ubuntu" ]]; then
            log_warning "This script is designed for Ubuntu systems only. Detected: $DISTRIB_ID" 1
        fi
        
        # Check for version 24.04 or 22.04 (for testing)
        if [[ "$DISTRIB_RELEASE" != "24.04" && "$DISTRIB_RELEASE" != "22.04" ]]; then
            log_warning "This script is designed for Ubuntu 24.04. Detected: $DISTRIB_RELEASE" 1
        fi
        log_success "Ubuntu version $DISTRIB_RELEASE: OK"
    else
        log_warning "Cannot determine Linux distribution. This script is designed for Ubuntu 24.04." 1
    fi
    
    # Update package lists
    log_message "Updating package lists..."
    apt-get -qq update
    if [ $? -ne 0 ]; then
        log_error "Failed to update package lists" 1
        exit 1
    fi
    log_success "Package lists updated"
    
    # Install base packages individually
    log_message "Checking base packages..."
    missing_packages=0
    for package in $BASE_PACKAGES; do
        if ! dpkg -l | grep -q "ii  $package "; then
            DEBIAN_FRONTEND=noninteractive apt-get -qq install -y $package
            if [ $? -ne 0 ]; then
                log_error "Failed to install: $package. Try installing it manually." 1
                missing_packages=1
            else
                log_message "Package installed: $package"
            fi
        else
            log_message "Package found: $package"
        fi
    done
    
    if [ $missing_packages -eq 1 ]; then
        log_error "Some base packages could not be installed" 1
        exit 1
    fi

    log_success "Base packages installed: OK"
    
    # Install additional packages if specified
    if [ -n "$PREREQUISITES_ADDITIONAL_PACKAGES" ]; then
        log_message "Checking additional packages..."
        for package in $PREREQUISITES_ADDITIONAL_PACKAGES; do
            # Check if package exists in repositories
            if ! apt-cache show $package &>/dev/null; then
                log_warning "Package not found in repositories: $package"
                continue
            fi
            
            if ! dpkg -l | grep -q "ii  $package "; then
                DEBIAN_FRONTEND=noninteractive apt-get -qq install -y $package
                if [ $? -ne 0 ]; then
                    log_warning "Failed to install: $package"
                else
                    log_message "Package installed: $package"
                fi
            else
                log_message "Package found: $package"
            fi
        done
        log_success "Additional packages check completed"
    fi
    
    log_success "Prerequisites check completed successfully"
    return 0
}