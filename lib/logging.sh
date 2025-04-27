#!/bin/bash
# Functions for logging and reporting

# Define color codes
COLOR_RESET="\033[0m"
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_CYAN="\033[0;36m"
COLOR_BOLD="\033[1m"

# Current task global variable
CURRENT_TASK="System"

# Set current task name
set_task() {
    CURRENT_TASK="$1"
}

# Initialize logging
init_logging() {
    # Create log header
    {
        echo "----------------------------------------"
        echo "Ubuntu Server Hardening Log"
        echo "Started: $(date)"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo "----------------------------------------"
    } > "$LOG_FILE"
    
    # Set permissions on log file
    chmod 600 "$LOG_FILE"
}

# Log a message to both console and log file
log_message() {
    local timestamp=$(date "+%Y-%m-%d/%H:%M:%S")
    local message="$1"
    
    # Log to file without colors
    echo "[$timestamp][$CURRENT_TASK] $message" >> "$LOG_FILE"
    
    # Output to console with colors - task is bold without color
    echo -e "[${COLOR_BOLD}$CURRENT_TASK${COLOR_RESET}] $message"
}

# Log an error message and exit if exit_code is provided
log_error() {
    local timestamp=$(date "+%Y-%m-%d/%H:%M:%S")
    local message="$1"
    local exit_code="${2:-}"
    
    # Log to file without colors
    echo "[$timestamp][$CURRENT_TASK][ERROR] $message" >> "$LOG_FILE"
    
    # Output to console with colors - task is bold and red
    echo -e "[${COLOR_BOLD}${COLOR_RED}$CURRENT_TASK${COLOR_RESET}][🛑] ${COLOR_RED}$message${COLOR_RESET}" >&2
    
    if [ -n "$exit_code" ]; then
        exit "$exit_code"
    fi
}

# Log a warning message
log_warning() {
    local timestamp=$(date "+%Y-%m-%d/%H:%M:%S")
    local message="$1"
    
    # Log to file without colors
    echo "[$timestamp][$CURRENT_TASK][WARNING] $message" >> "$LOG_FILE"
    
    # Output to console with colors - task is bold and yellow
    echo -e "[${COLOR_BOLD}${COLOR_YELLOW}$CURRENT_TASK${COLOR_RESET}][⚠️] ${COLOR_YELLOW}$message${COLOR_RESET}" >&2
}

# Log a success message
log_success() {
    local timestamp=$(date "+%Y-%m-%d/%H:%M:%S")
    local message="$1"
    
    # Log to file without colors
    echo "[$timestamp][$CURRENT_TASK][SUCCESS] $message" >> "$LOG_FILE"
    
    # Output to console with colors - task is bold and green
    echo -e "[${COLOR_BOLD}${COLOR_GREEN}$CURRENT_TASK${COLOR_RESET}][✅] ${COLOR_GREEN}$message${COLOR_RESET}"
}

log_file() {
    local timestamp=$(date "+%Y-%m-%d/%H:%M:%S")
    local message="$1"
    local task="$2"
    
     # Log to file only without colors
    echo "[$timestamp][$task] $message" >> "$LOG_FILE"
}