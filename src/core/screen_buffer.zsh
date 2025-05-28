# File: screen_buffer.zsh
# Purpose: Virtual screen buffer and diff-based rendering.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Source logging for internal messages
source "$(dirname "$0")/logging.zsh"

# Global arrays for the screen buffers
# Key: "y,x", Value: "char:attr_id"
typeset -gA ZIF_SCREEN_CURRENT_BUFFER
typeset -gA ZIF_SCREEN_PREVIOUS_BUFFER

# Function: screen_buffer_init
# Purpose: Initializes or re-initializes the screen buffers using global LINES and COLS.
# Details:
#   Clears and then populates both CURRENT and PREVIOUS buffers with " :normal".
#   Uses global $LINES and $COLS variables provided by zsh/curses after `zcurses init`.
screen_buffer_init() {
    local y x

    if [[ -z "$LINES" || -z "$COLS" ]]; then
        log_error "screen_buffer_init: LINES or COLS not set. Cannot initialize buffer."
        # Optionally, set default small size or return error
        # For now, proceed but log this critical issue.
        # This function relies on zcurses init having set these globals.
        return 1
    fi

    # Clear existing buffers
    ZIF_SCREEN_CURRENT_BUFFER=()
    ZIF_SCREEN_PREVIOUS_BUFFER=()
    
    # Default cell format: "char:fg_color:bg_color:attributes_list"
    local default_cell_value=" :default:default:" # Space, default fg, default bg, no attributes

    for ((y = 0; y < LINES; y++)); do
        for ((x = 0; x < COLS; x++)); do
            ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]="$default_cell_value"
            ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]="$default_cell_value" # Initialize previous buffer
        done
    done
    log_info "Screen buffer initialized with ${LINES}x${COLS}. Default cell: '$default_cell_value'"
}

# Function: screen_buffer_set_cell
# Purpose: Sets the character, colors, and attributes for a cell in the current screen buffer.
# Arguments:
#   $1 (y): The row coordinate.
#   $2 (x): The column coordinate.
#   $3 (char): The character to place in the cell (should be a single character).
#   $4 (fg_color): Optional. Foreground color. Defaults to "default".
#   $5 (bg_color): Optional. Background color. Defaults to "default".
#   $6 (attributes_string): Optional. Comma-separated string of attributes (e.g., "bold,underline"). Defaults to "".
screen_buffer_set_cell() {
    local y="$1"
    local x="$2"
    local char="$3"
    local fg_color="${4:-default}"
    local bg_color="${5:-default}"
    local attributes_string="${6:-}" # Defaults to empty string

    # Basic validation for char length
    if (( ${#char} != 1 )); then
        log_warn "screen_buffer_set_cell: char argument must be a single character. Received: '$char'"
        return 1
    fi

    ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]="$char:$fg_color:$bg_color:$attributes_string"
}

# Function: screen_buffer_get_cell
# Purpose: Retrieves the content (char:attr_id) of a cell from the current screen buffer.
# Arguments:
#   $1 (y): The row coordinate.
#   $2 (x): The column coordinate.
# Returns:
#   The string "char:attr_id" from the current buffer for the given cell.
#   Returns an empty string or a default if the cell is not found (though init should prevent this).
screen_buffer_get_cell() {
    local y="$1"
    local x="$2"
    echo "${ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]:- :error}" # Default to " :error" if cell somehow missing
}

# Function: render_diff_and_draw
# Purpose: Compares the current buffer to the previous buffer and draws only the differences.
# Details:
#   Iterates through all screen cells. If a cell in CURRENT_BUFFER differs from
#   PREVIOUS_BUFFER, it's drawn to the screen, and PREVIOUS_BUFFER is updated.
#   Finally, calls zcurses_refresh to display all changes.
#   Uses global $LINES and $COLS variables.
render_diff_and_draw() {
    local y x
    local current_cell_value previous_cell_value
    local char attr_id

    # Ensure LINES and COLS are available
    if [[ -z "$LINES" || -z "$COLS" ]]; then
        log_error "render_diff_and_draw: LINES or COLS not set. Cannot render."
        return 1
    fi

    for ((y = 0; y < LINES; y++)); do
        for ((x = 0; x < COLS; x++)); do
            current_cell_value="${ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]}"
            previous_cell_value="${ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]}"

            if [[ "$current_cell_value" != "$previous_cell_value" ]]; then
                # Parse "char:fg_color:bg_color:attributes_list"
                local char fg bg attrs_str
                IFS=: read -r char fg bg attrs_str <<< "$current_cell_value"
                # Note: If attributes_string can be empty, read might behave unexpectedly for the last var.
                # A more robust parsing if attrs_str can be empty:
                # char="${current_cell_value%%:*}"
                # local temp1="${current_cell_value#*:}"
                # fg="${temp1%%:*}"
                # local temp2="${temp1#*:}"
                # bg="${temp2%%:*}"
                # attrs_str="${temp2#*:}" # This will be empty if no fourth colon

                # Reset attributes and colors first (simplest approach for now)
                # `default/default` resets colors. Attributes need explicit reset.
                zcurses attr stdscr default/default
                zcurses attr stdscr -bold -underline -reverse -standout -dim -blink # Turn off all known attributes

                # Apply new colors
                if [[ -n "$fg" && -n "$bg" ]]; then # Ensure fg and bg are not empty
                    zcurses attr stdscr "$fg/$bg"
                fi

                # Apply new text attributes
                if [[ -n "$attrs_str" ]]; then
                    local -a attrs_array
                    attrs_array=(${(s:,:)attrs_str})
                    local attr
                    for attr in "${attrs_array[@]}"; do
                        if [[ -n "$attr" ]]; then # Ensure attribute name is not empty
                            zcurses attr stdscr "+$attr"
                        fi
                    done
                fi
                
                zcurses move "$y" "$x"
                zcurses char stdscr -- "$char" # Draw the single character
                
                ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]="$current_cell_value"
            fi
        done
    done
    zcurses refresh
}

# Function: screen_buffer_clear_current
# Purpose: Resets all cells in the current screen buffer to a default state.
# Details:
#   This is typically called at the beginning of a new frame render cycle,
#   before UI elements draw their content to the current buffer.
#   Uses global $LINES and $COLS variables.
screen_buffer_clear_current() {
    local y x
    local default_cell_value=" :default:default:" # Space, default fg, default bg, no attributes
    
    if [[ -z "$LINES" || -z "$COLS" ]]; then
        log_error "screen_buffer_clear_current: LINES or COLS not set. Cannot clear."
        return 1
    fi

    for ((y = 0; y < LINES; y++)); do
        for ((x = 0; x < COLS; x++)); do
            ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]="$default_cell_value"
        done
    done
    # log_debug "Screen current buffer cleared." # Optional: can be too verbose
}
