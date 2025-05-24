# File: logging.zsh
# Purpose: Logging utilities for the Zif Framework.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Global variable for the log file path.
# Defaults to a file in the user's home .cache directory.
typeset -g ZIF_LOG_FILE="${HOME}/.cache/zif_framework/app.log"

# Global variable for the current logging level.
# Determines which messages are written to the log file.
# Possible values: DEBUG, INFO, WARN, ERROR, CRITICAL
typeset -g ZIF_LOG_LEVEL="INFO"

# Associative array to map log level names to numerical values.
# Lower numbers indicate higher verbosity.
typeset -gA ZIF_LOG_LEVEL_VALUES
ZIF_LOG_LEVEL_VALUES=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [CRITICAL]=4
)

# Function: logging_get_level_value
# Purpose: Converts a log level name (string) to its numerical representation.
# Arguments:
#   $1 (level_name): The log level string (e.g., "INFO", "DEBUG").
# Returns:
#   The numerical value of the log level. Returns 99 for unknown levels.
logging_get_level_value() {
    local level_name="${1:-$ZIF_LOG_LEVEL}" # Default to global if not provided
    echo "${ZIF_LOG_LEVEL_VALUES[$level_name]:-99}" # Return 99 if level not found
}

# Function: log_message
# Purpose: Logs a message to the configured log file if its level is appropriate.
# Arguments:
#   $1 (log_level_name): The severity level of the message (e.g., "INFO", "ERROR").
#   $2 (message): The message string to log.
#
# Details:
#   - Checks if the provided log_level_name meets the global ZIF_LOG_LEVEL threshold.
#   - Creates the log directory if it doesn't exist.
#   - Appends the formatted message (timestamp, level, message) to ZIF_LOG_FILE.
log_message() {
    local log_level_name="$1"
    local message="$2"

    local current_level_value
    local message_level_value

    message_level_value=$(logging_get_level_value "$log_level_name")
    current_level_value=$(logging_get_level_value "$ZIF_LOG_LEVEL")

    # Only log if the message's level is greater than or equal to the global log level
    if (( message_level_value < current_level_value )); then
        return 0 # Do not log, message severity is below current log level
    fi

    # Ensure the log directory exists
    local log_dir
    log_dir=$(dirname "$ZIF_LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            echo "Error: Could not create log directory: $log_dir" >&2
            return 1
        }
    fi

    # Append the formatted log entry to the log file
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_level_name] $message" >> "$ZIF_LOG_FILE"
}

# Helper functions for each log level

# Function: log_debug
# Purpose: Logs a message with DEBUG level.
# Arguments: $1 (message)
log_debug() {
    log_message "DEBUG" "$1"
}

# Function: log_info
# Purpose: Logs a message with INFO level.
# Arguments: $1 (message)
log_info() {
    log_message "INFO" "$1"
}

# Function: log_warn
# Purpose: Logs a message with WARN level.
# Arguments: $1 (message)
log_warn() {
    log_message "WARN" "$1"
}

# Function: log_error
# Purpose: Logs a message with ERROR level.
# Arguments: $1 (message)
log_error() {
    log_message "ERROR" "$1"
}

# Function: log_critical
# Purpose: Logs a message with CRITICAL level.
# Arguments: $1 (message)
log_critical() {
    log_message "CRITICAL" "$1"
}
