# File: events.zsh
# Purpose: Event handling and dispatch.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Source required core modules
source "$(dirname "$0")/keybinds.zsh"
source "$(dirname "$0")/state.zsh"
# Ensure logging is available for focus change logs if state_set_current_focus_id uses it.
# main.zsh already sources logging.zsh, so it should be available in the environment
# where event_process_keypress and other event functions are called.
# However, to be absolutely safe for any direct calls or future refactoring:
if ! typeset -f log_debug > /dev/null; then
    source "$(dirname "$0")/logging.zsh"
fi

# Function: event_focus_set
# Purpose: Sets the current focus to the specified widget ID.
# Arguments:
#   $1 (widget_id): The ID of the widget to focus.
# Details:
#   Calls state_set_current_focus_id to update the global state.
#   Future: Could trigger redraws or specific actions for the newly focused widget.
event_focus_set() {
    local widget_id="$1"
    state_set_current_focus_id "$widget_id"
    # log_debug "Focus set to: $widget_id" # state_set_current_focus_id already logs this
}

# Function: event_focus_next
# Purpose: Moves focus to the next focusable element in the defined focus order.
# Details:
#   Retrieves current focus ID and focus order from state.zsh.
#   Calculates the next focus ID, wrapping around to the beginning if necessary.
#   Calls event_focus_set with the new focus ID.
event_focus_next() {
    local current_focus_id
    current_focus_id=$(state_get_current_focus_id)
    
    local -a focus_order_array
    # Correctly populate the array from the output of state_get_focus_order
    # state_get_focus_order prints each element on a new line.
    focus_order_array=(${(f)"$(state_get_focus_order)"})

    if (( ${#focus_order_array[@]} == 0 )); then
        log_warn "Focus order array is empty. Cannot change focus."
        return 1
    fi

    local current_index=-1
    local i
    for i in {1..${#focus_order_array[@]}}; do
        if [[ "${focus_order_array[$i]}" == "$current_focus_id" ]]; then
            current_index=$((i - 1)) # Zsh arrays are 1-indexed by default in this context
            break
        fi
    done

    local next_index
    if [[ $current_index -eq -1 ]]; then
        # Current focus ID not found in order, default to first element
        log_warn "Current focus '$current_focus_id' not in focus order. Focusing first element."
        next_index=0
    else
        next_index=$((current_index + 1))
        if [[ $next_index -ge ${#focus_order_array[@]} ]]; then
            next_index=0 # Wrap around to the beginning
        fi
    fi
    
    event_focus_set "${focus_order_array[$((next_index + 1))]}" # Convert back to 1-based index for array access
}

# Function: event_focus_previous
# Purpose: Moves focus to the previous focusable element in the defined focus order.
# Details:
#   Retrieves current focus ID and focus order from state.zsh.
#   Calculates the previous focus ID, wrapping around to the end if necessary.
#   Calls event_focus_set with the new focus ID.
event_focus_previous() {
    local current_focus_id
    current_focus_id=$(state_get_current_focus_id)

    local -a focus_order_array
    focus_order_array=(${(f)"$(state_get_focus_order)"})

    if (( ${#focus_order_array[@]} == 0 )); then
        log_warn "Focus order array is empty. Cannot change focus."
        return 1
    fi

    local current_index=-1
    local i
    for i in {1..${#focus_order_array[@]}}; do
        if [[ "${focus_order_array[$i]}" == "$current_focus_id" ]]; then
            current_index=$((i - 1)) # Zsh arrays are 1-indexed
            break
        fi
    done

    local prev_index
    if [[ $current_index -eq -1 ]]; then
        # Current focus ID not found in order, default to last element
        log_warn "Current focus '$current_focus_id' not in focus order. Focusing last element."
        prev_index=$((${#focus_order_array[@]} - 1))
    else
        prev_index=$((current_index - 1))
        if [[ $prev_index -lt 0 ]]; then
            prev_index=$((${#focus_order_array[@]} - 1)) # Wrap around to the end
        fi
    fi
    
    event_focus_set "${focus_order_array[$((prev_index + 1))]}" # Convert back to 1-based index
}


# Function: event_process_keypress
# Purpose: Processes input events (keypress or mouse)
# Arguments:
#   $1 (key_char): The character input, if any.
#   $2 (key_name): The name of the key pressed (e.g., "KEY_UP", "KEY_MOUSE"), if any.
#   $@ (mouse_data_array): Remaining arguments are elements of the mouse data array.
#
# Details:
#   If key_name is "KEY_MOUSE", it calls event_process_mouse_event.
#   Otherwise, it treats it as a standard keypress, determines the associated action
#   using keybind_get_action (based on key_char or key_name), and then performs the action.
event_process_keypress() {
    local key_char="$1"
    local key_name="$2"
    shift 2 # Remove key_char and key_name from argument list
    typeset -a mouse_data_array=("$@") # Capture remaining args as mouse data

    log_debug "event_process_keypress: char='${key_char}', name='${key_name}', mouse_data_count=${#mouse_data_array[@]}"

    if [[ "$key_name" == "KEY_MOUSE" ]]; then
        # Call event_process_mouse_event with the mouse_data_array elements
        event_process_mouse_event "${mouse_data_array[@]}"
        return 0 # Mouse event handled
    fi

    # If not a mouse event, proceed with normal keybinding lookup.
    # Prefer key_name if available (e.g. for special keys like arrow keys if bound later)
    # Otherwise, use key_char.
    local action_key_input="$key_char"
    # Potentially, keybind_get_action could be enhanced to also check key_name if key_char is empty.
    # For now, it primarily uses key_char.
    
    local action
    action=$(keybind_get_action "$action_key_input")

    # Handle the action based on key_char (or key_name if action_key_input is adapted)
    case "$action" in
        "quit")
            state_quit_app # Call function from state.zsh to signal application quit
            ;;
        "focus_next")
            event_focus_next
            ;;
        "focus_prev")
            event_focus_previous
            ;;
        "")
            # No action bound to this key, can be ignored or logged
            if [[ -n "$key_char" || -n "$key_name" ]]; then # Log only if there was some input
                 log_debug "No action defined for key_char='${key_char}', key_name='${key_name}'"
            fi
            ;;
        *)
            # Placeholder for future actions
            log_warn "Action '$action' recognized but not yet implemented for key_char='${key_char}', key_name='${key_name}'"
            ;;
    esac
}

# Function: event_process_mouse_event
# Purpose: Handles mouse events.
# Arguments:
#   $@ (event_details): Array of mouse event details from `zcurses input` (mparam).
#
# Details:
#   Extracts mouse coordinates and button/event information directly from the event_details array.
#   Logs the event and checks if the quit button was clicked.
event_process_mouse_event() {
    typeset -a event_details=("$@") # Capture all arguments into event_details array

    # Extract mouse event details from the array (1-indexed for zsh arrays)
    local device_id="${event_details[1]}"
    # Note: zcurses input stores screen_y (curses Y) then screen_x (curses X).
    # The documentation for `zcurses input` states parameters are:
    # char, keyname, mparam (array)
    # mparam elements: device_id, screen_y, screen_x, screen_z, event_type_1, event_type_2, ...
    # So, X is event_details[3] and Y is event_details[2] according to typical curses/screen order.
    # However, the problem description consistently uses X then Y from array.
    # Let's stick to the problem description's indexing for this task:
    # mouse_x = event_details[2], mouse_y = event_details[3]
    local mouse_x="${event_details[2]}" 
    local mouse_y="${event_details[3]}"
    local mouse_z="${event_details[4]}" # Usually 0

    # Log the extracted mouse event details
    # Array slicing ${array[5,-1]} gets elements from 5th to the end.
    log_debug "Mouse event (from zcurses input mparam): X=$mouse_x, Y=$mouse_y, Z=$mouse_z, DeviceID=$device_id, Events: ${event_details[5,-1]}"

    # Check for quit button click
    # Quit button is at Y=1, X from 1 to 3.
    # Search for "PRESSED1" or "CLICKED1" in the event types (from 5th element onwards)
    local main_mouse_action=""
    local i
    for i in {5..${#event_details[@]}}; do
        if [[ "${event_details[$i]}" == "PRESSED1" || "${event_details[$i]}" == "CLICKED1" ]]; then
            main_mouse_action="${event_details[$i]}"
            break
        fi
    done

    if [[ $mouse_y -eq 1 && $mouse_x -ge 1 && $mouse_x -le 3 && -n "$main_mouse_action" ]]; then
        log_info "Quit button clicked via mouse (X:$mouse_x, Y:$mouse_y, Action:$main_mouse_action)!"
        state_quit_app
    fi
    # Future: Could dispatch to other UI elements based on coordinates.
}
