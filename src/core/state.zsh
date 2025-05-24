# File: state.zsh
# Purpose: Global state management and update functions.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Declare a global associative array to hold the application state.
typeset -gA ZIF_STATE

# Declare a global associative array to hold focusable areas/widgets and their coordinates.
# Example: ZIF_FOCUS_AREAS[widget_id]="y_start x_start height width"
# This will be populated by widgets when they register themselves.
typeset -gA ZIF_FOCUS_AREAS

# Initialize the application state
ZIF_STATE=(
    APP_SHOULD_RUN "true"
    CURRENT_VIEW "main_menu"
    current_focus_id "top_bar_quit_button" # Default focus
    focus_order ("top_bar_quit_button" "top_bar_title" "main_content_area") # Conceptual order
)

# Function: state_get
# Purpose: Retrieves a value from the global application state.
# Arguments:
#   $1 (key_name): The name of the state key to retrieve.
# Returns:
#   The value of ZIF_STATE[$key_name].
state_get() {
    local key_name="$1"
    echo "${ZIF_STATE[$key_name]}"
}

# Function: state_set
# Purpose: Sets a value in the global application state.
# Arguments:
#   $1 (key_name): The name of the state key to set.
#   $2 (value): The value to set for the key.
state_set() {
    local key_name="$1"
    local value="$2"
    ZIF_STATE[$key_name]="$value"
}

# Function: state_app_is_running
# Purpose: Checks if the application is currently marked as running.
# Returns:
#   0 (true) if ZIF_STATE[APP_SHOULD_RUN] is "true".
#   1 (false) otherwise.
state_app_is_running() {
    if [[ "${ZIF_STATE[APP_SHOULD_RUN]}" == "true" ]]; then
        return 0 # true
    else
        return 1 # false
    fi
}

# Function: state_quit_app
# Purpose: Sets the application state to stop running.
state_quit_app() {
    ZIF_STATE[APP_SHOULD_RUN]="false"
}

# Function: state_get_current_focus_id
# Purpose: Retrieves the ID of the currently focused UI element.
# Returns:
#   The ID string of the currently focused element (e.g., "top_bar_quit_button").
state_get_current_focus_id() {
    echo "${ZIF_STATE[current_focus_id]}"
}

# Function: state_set_current_focus_id
# Purpose: Sets the ID of the currently focused UI element.
# Arguments:
#   $1 (new_focus_id): The ID string of the element to set focus to.
# Details:
#   Logs the focus change using log_debug.
state_set_current_focus_id() {
    local new_focus_id="$1"
    ZIF_STATE[current_focus_id]="$new_focus_id"
    # Assuming log_debug is available (sourced by a higher-level script like main.zsh or event handler)
    # If logging.zsh is not guaranteed to be sourced when state.zsh is, this could be problematic.
    # However, state_set_current_focus_id is likely called from places where logging is available.
    if typeset -f log_debug > /dev/null; then
        log_debug "Focus changed to: $new_focus_id"
    fi
}

# Function: state_get_focus_order
# Purpose: Retrieves the defined order of focusable elements.
# Returns:
#   A list of focusable element IDs in their defined order.
#   Each ID is printed on a new line if captured by command substitution.
#   If used directly in an array assignment `my_array=($(state_get_focus_order))`,
#   it will populate the array correctly.
state_get_focus_order() {
    # The 'focus_order' element in ZIF_STATE is already an array.
    # We need to correctly expand its elements.
    # Using print -r -- ensures each element is printed raw, one per line if array is expanded in string context by some shells,
    # but when captured by `arr=($(command))` it works fine.
    # Or, to return space-separated string for easy array conversion: echo "${(@)ZIF_STATE[focus_order]}"
    print -r -- "${ZIF_STATE[focus_order]}"
}
