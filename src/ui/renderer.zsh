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
#   $5 (fg_color): Optional. Foreground color. Defaults to "default".
#   $6 (bg_color): Optional. Background color. Defaults to "default".
#   $7 (attributes_string): Optional. Comma-separated string of attributes. Defaults to "".
render_draw_box() {
    local y_start="$1"
    local x_start="$2"
    local height="$3"
    local width="$4"
    local fg_color="${5:-default}"
    local bg_color="${6:-default}"
    local attributes_string="${7:-}"
    local i

    # Ensure width and height are at least 2 to draw a box
    if (( width < 2 || height < 2 )); then
        log_warn "render_draw_box: Box width and height must be at least 2."
        return 1
    fi

    # Draw top border
    screen_buffer_set_cell "$y_start" "$x_start" "┌" "$fg_color" "$bg_color" "$attributes_string"
    for i in {1..$((width - 2))}; do
        screen_buffer_set_cell "$y_start" $((x_start + i)) "─" "$fg_color" "$bg_color" "$attributes_string"
    done
    screen_buffer_set_cell "$y_start" $((x_start + width - 1)) "┐" "$fg_color" "$bg_color" "$attributes_string"

    # Draw side borders
    for i in {1..$((height - 2))}; do
        screen_buffer_set_cell $((y_start + i)) "$x_start" "│" "$fg_color" "$bg_color" "$attributes_string"
        screen_buffer_set_cell $((y_start + i)) $((x_start + width - 1)) "│" "$fg_color" "$bg_color" "$attributes_string"
    done

    # Draw bottom border
    screen_buffer_set_cell $((y_start + height - 1)) "$x_start" "└" "$fg_color" "$bg_color" "$attributes_string"
    for i in {1..$((width - 2))}; do
        screen_buffer_set_cell $((y_start + height - 1)) $((x_start + i)) "─" "$fg_color" "$bg_color" "$attributes_string"
    done
    screen_buffer_set_cell $((y_start + height - 1)) $((x_start + width - 1)) "┘" "$fg_color" "$bg_color" "$attributes_string"
}

# Function: render_draw_text
# Purpose: Draws text to the screen buffer at a specified position with given attributes.
# Arguments:
#   $1 (y): The row (Y coordinate) to draw the text.
#   $2 (x_start): The starting column (X coordinate) for the text.
#   $3 (text): The text string to draw.
#   $4 (fg_color): Optional. Foreground color. Defaults to "default".
#   $5 (bg_color): Optional. Background color. Defaults to "default".
#   $6 (attributes_string): Optional. Comma-separated string of attributes. Defaults to "".
render_draw_text() {
    local y="$1"
    local x_start="$2"
    local text="$3"
    local fg_color="${4:-default}"
    local bg_color="${5:-default}"
    local attributes_string="${6:-}"
    
    local current_x="$x_start"
    local char
    
    local -a chars
    chars=(${(s::)text})

    for char in "${chars[@]}"; do
        # TODO: Add check for current_x exceeding screen width (COLS)
        screen_buffer_set_cell "$y" "$current_x" "$char" "$fg_color" "$bg_color" "$attributes_string"
        current_x=$((current_x + 1))
    done
}
