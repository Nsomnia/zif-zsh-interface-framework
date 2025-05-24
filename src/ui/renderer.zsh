# File: renderer.zsh
# Purpose: Functions responsible for drawing elements to the screen via the screen buffer.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Source screen buffer functions
# Assuming this file (renderer.zsh) is in src/ui/ and screen_buffer.zsh is in src/core/
source "$(dirname "$0")/../core/screen_buffer.zsh"

# Function: render_draw_box
# Purpose: Draws a box to the screen buffer using Unicode box-drawing characters.
# Arguments:
#   $1 (y_start): The starting row (Y coordinate).
#   $2 (x_start): The starting column (X coordinate).
#   $3 (height): The height of the box.
#   $4 (width): The width of the box.
#   $5 (attr_id): Optional. The attribute ID for the box characters. Defaults to "normal".
render_draw_box() {
    local y_start="$1"
    local x_start="$2"
    local height="$3"
    local width="$4"
    local attr_id="${5:-normal}"
    local i

    # Ensure width and height are at least 2 to draw a box
    if (( width < 2 || height < 2 )); then
        log_warn "render_draw_box: Box width and height must be at least 2."
        return 1
    fi

    # Draw top border
    screen_buffer_set_cell "$y_start" "$x_start" "┌" "$attr_id"
    for i in {1..$((width - 2))}; do
        screen_buffer_set_cell "$y_start" $((x_start + i)) "─" "$attr_id"
    done
    screen_buffer_set_cell "$y_start" $((x_start + width - 1)) "┐" "$attr_id"

    # Draw side borders
    for i in {1..$((height - 2))}; do
        screen_buffer_set_cell $((y_start + i)) "$x_start" "│" "$attr_id"
        screen_buffer_set_cell $((y_start + i)) $((x_start + width - 1)) "│" "$attr_id"
    done

    # Draw bottom border
    screen_buffer_set_cell $((y_start + height - 1)) "$x_start" "└" "$attr_id"
    for i in {1..$((width - 2))}; do
        screen_buffer_set_cell $((y_start + height - 1)) $((x_start + i)) "─" "$attr_id"
    done
    screen_buffer_set_cell $((y_start + height - 1)) $((x_start + width - 1)) "┘" "$attr_id"
}

# Function: render_draw_text
# Purpose: Draws text to the screen buffer at a specified position.
# Arguments:
#   $1 (y): The row (Y coordinate) to draw the text.
#   $2 (x): The column (X coordinate) to draw thetext.
#   $3 (text): The text string to draw.
#   $4 (attr_id): Optional. The attribute ID for the text. Defaults to "normal".
render_draw_text() {
    local y="$1"
    local x_start="$2" # Renamed x to x_start for clarity
    local text="$3"
    local attr_id="${4:-normal}"
    
    local current_x="$x_start"
    local char
    
    # Iterate over each character in the text string.
    # This simple iteration handles single-byte characters correctly.
    # For multi-byte characters, `grep -o .` or similar is better but adds dependency.
    # Zsh's `${(s::)text}` splits into an array of characters.
    local -a chars
    chars=(${(s::)text})

    for char in "${chars[@]}"; do
        # TODO: Add check for current_x exceeding screen width (STTY_COLS)
        screen_buffer_set_cell "$y" "$current_x" "$char" "$attr_id"
        current_x=$((current_x + 1))
    done
}
