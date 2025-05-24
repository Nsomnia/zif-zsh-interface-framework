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
# Purpose: Initializes or re-initializes the screen buffers.
# Arguments:
#   $1 (rows): The number of rows for the screen buffer.
#   $2 (cols): The number of columns for the screen buffer.
# Details:
#   Clears and then populates both CURRENT and PREVIOUS buffers with " :normal".
screen_buffer_init() {
    local rows="$1"
    local cols="$2"
    local y x

    # Clear existing buffers
    ZIF_SCREEN_CURRENT_BUFFER=()
    ZIF_SCREEN_PREVIOUS_BUFFER=()

    for ((y = 0; y < rows; y++)); do
        for ((x = 0; x < cols; x++)); do
            ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]=" :normal"
            ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]=" :normal" # Initialize previous buffer to a known state
        done
    done
    log_info "Screen buffer initialized with ${rows}x${cols}"
}

# Function: screen_buffer_set_cell
# Purpose: Sets the character and attribute for a cell in the current screen buffer.
# Arguments:
#   $1 (y): The row coordinate.
#   $2 (x): The column coordinate.
#   $3 (char): The character to place in the cell (should be a single character).
#   $4 (attr_id): Optional. The attribute ID for the character (e.g., "normal", "highlight"). Defaults to "normal".
screen_buffer_set_cell() {
    local y="$1"
    local x="$2"
    local char="$3"
    local attr_id="${4:-normal}" # Default to "normal" if not provided

    # Basic validation for char length (optional, but good practice)
    if (( ${#char} != 1 )); then
        log_warn "screen_buffer_set_cell: char argument must be a single character. Received: '$char'"
        # Decide on handling: truncate, use a placeholder, or skip. For now, skip update.
        return 1
    fi

    ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]="$char:$attr_id"
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
#   Assumes STTY_ROWS and STTY_COLS are available from zsh/curses.
render_diff_and_draw() {
    local y x
    local current_cell_value previous_cell_value
    local char attr_id

    # STTY_ROWS and STTY_COLS are provided by zsh/curses
    # Ensure they are available, otherwise default or log error
    if [[ -z "$STTY_ROWS" || -z "$STTY_COLS" ]]; then
        log_error "render_diff_and_draw: STTY_ROWS or STTY_COLS not set. Cannot render."
        return 1
    fi

    for ((y = 0; y < STTY_ROWS; y++)); do
        for ((x = 0; x < STTY_COLS; x++)); do
            current_cell_value="${ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]}"
            previous_cell_value="${ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]}"

            if [[ "$current_cell_value" != "$previous_cell_value" ]]; then
                # Parse "char:attr_id"
                # Zsh parameter expansion: ${string%%pat} remove longest suffix, ${string#pat} remove shortest prefix
                char="${current_cell_value[1]}" # First character of the value string
                attr_id="${current_cell_value#*:}" # Substring after the first colon

                # Placeholder for attribute handling based on attr_id
                # Example: if [[ "$attr_id" == "highlight" ]]; then zcurses_attr_on curses_standout; fi
                # For now, just draw the character.

                zcurses_move "$y" "$x"
                zcurses_putc "$char" # Use zcurses_putc for single characters

                # if [[ "$attr_id" == "highlight" ]]; then zcurses_attr_off curses_standout; fi
                
                ZIF_SCREEN_PREVIOUS_BUFFER["$y,$x"]="$current_cell_value"
            fi
        done
    done
    zcurses_refresh
}

# Function: screen_buffer_clear_current
# Purpose: Resets all cells in the current screen buffer to a default state.
# Details:
#   This is typically called at the beginning of a new frame render cycle,
#   before UI elements draw their content to the current buffer.
#   Assumes STTY_ROWS and STTY_COLS are available.
screen_buffer_clear_current() {
    local y x
    
    if [[ -z "$STTY_ROWS" || -z "$STTY_COLS" ]]; then
        log_error "screen_buffer_clear_current: STTY_ROWS or STTY_COLS not set. Cannot clear."
        return 1
    fi

    for ((y = 0; y < STTY_ROWS; y++)); do
        for ((x = 0; x < STTY_COLS; x++)); do
            ZIF_SCREEN_CURRENT_BUFFER["$y,$x"]=" :normal"
        done
    done
    # log_debug "Screen current buffer cleared." # Optional: can be too verbose
}
