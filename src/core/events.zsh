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
# Purpose: Processes a keypress event by mapping it to an action and executing it.
# Arguments:
#   $1 (key_char): The character input from the user (passed from zcurses_getch).
#
# Details:
#   This function first checks if the input corresponds to a mouse event.
#   If it's a mouse event, it calls `event_process_mouse_event`.
#   Otherwise, it treats it as a standard keypress, determines the associated action
#   using `keybind_get_action`, and then performs the action.
event_process_keypress() {
    local key_char="$1" # This is the raw character from zcurses_getch
    local action

    # zcurses_getch also sets several global variables, including:
    # MOUSE_X, MOUSE_Y, MOUSE_BUTTON (if it was a mouse event)
    # zcurses_key (a string like "KEY_MOUSE", "KEY_UP", or the character itself if printable)
    # zcurses_keyname (a human-readable name)

    # Check if the event was a mouse event
    # The variable $zcurses_key is set by zcurses_getch
    if [[ "$zcurses_key" == "KEY_MOUSE" ]]; then
        event_process_mouse_event
        return 0 # Mouse event handled
    fi

    # If not a mouse event, proceed with normal keybinding lookup
    # Note: key_char might be empty or special for non-printable keys if not KEY_MOUSE
    # keybind_get_action should handle this gracefully (e.g. return no action)
    action=$(keybind_get_action "$key_char")

    # Handle the action
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
            # echo "No action for key: $key_char" # Uncomment for debugging
            ;;
        *)
            # Placeholder for future actions
            echo "Action '$action' recognized but not yet implemented for key: $key_char"
            ;;
    esac
}
