#!/bin/bash
# Functions for user management and permissions

# Function to create a new user and set up SSH key
configure_user() {
    log_message "Creating new user: $USER_NAME"
    
    # Create user
    useradd -m -s /bin/bash "$USER_NAME"
    if [ $? -ne 0 ]; then
        log_error "Failed to create user: $USER_NAME" 1
        exit 1
    fi
    
    # Set password
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd
    if [ $? -ne 0 ]; then
        log_error "Failed to set password for user: $USER_NAME" 1
        exit 1
    fi
    
    # Add to sudo group if specified
    if [ "$USER_ADD_TO_SUDO" = "true" ]; then
        log_message "Adding $USER_NAME to sudo group"
        usermod -aG sudo "$USER_NAME"
        if [ $? -ne 0 ]; then
            log_error "Failed to add $USER_NAME to sudo group" 1
            exit 1
        fi
    fi
    
    # Set up SSH key
    log_message "Setting up SSH key for $USER_NAME"
    mkdir -p /home/"$USER_NAME"/.ssh
    echo "$SSH_KEY" > /home/"$USER_NAME"/.ssh/authorized_keys
    chmod 700 /home/"$USER_NAME"/.ssh
    chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
    chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"/.ssh
    
    # Set root password if specified
    if [ -n "$ROOT_PASSWORD" ]; then
        log_message "Setting root password"
        echo "root:$ROOT_PASSWORD" | chpasswd
        if [ $? -ne 0 ]; then
            log_error "Failed to set root password" 1
            exit 1
        fi
    fi
    
    log_success "User $USER_NAME created successfully"
}
