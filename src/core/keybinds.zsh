# File: keybinds.zsh
# Purpose: Keybinding definitions and lookup.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Declare a global associative array to hold keybindings.
# Keys are action names, values are the character sequences.
typeset -gA ZIF_KEYBINDS

# Initialize default keybindings
ZIF_KEYBINDS=(
    [quit]="q"         # Action 'quit' is bound to the 'q' key
    [focus_next]="t"   # Action 'focus_next' is bound to the 't' key
    [focus_prev]="T"   # Action 'focus_prev' is bound to the 'T' (Shift+t) key
)

# Function: keybind_get_action
# Purpose: Retrieves the action associated with a given key character.
# Arguments:
#   $1 (key_char): The key character pressed by the user.
# Returns:
#   The name of the action if the key_char is bound (e.g., "quit").
#   An empty string if the key_char is not bound to any action.
keybind_get_action() {
    local key_char="$1"
    local action_name=""

    # Iterate through the ZIF_KEYBINDS associative array
    # The key is the action name, the value is the character
    for action in ${(k)ZIF_KEYBINDS}; do
        if [[ "${ZIF_KEYBINDS[$action]}" == "$key_char" ]]; then
            action_name="$action"
            break
        fi
    done

    echo "$action_name"
}
