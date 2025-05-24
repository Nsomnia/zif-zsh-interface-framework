# File: layout.zsh
# Purpose: Functions for screen layout, panel division.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Source the renderer for drawing capabilities
source "$(dirname "$0")/renderer.zsh"

# Source the button widget
source "$(dirname "$0")/widgets/button.zsh"

# Global variables for top bar dimensions (will be set by layout_get_top_bar_dims)
typeset -g LAYOUT_TOP_BAR_Y
typeset -g LAYOUT_TOP_BAR_X
typeset -g LAYOUT_TOP_BAR_H
typeset -g LAYOUT_TOP_BAR_W

# Function: layout_get_top_bar_dims
# Purpose: Calculates and sets the dimensions for the top bar.
# Details:
#   Sets global variables:
#     LAYOUT_TOP_BAR_Y: Starting Y coordinate (row) of the top bar.
#     LAYOUT_TOP_BAR_X: Starting X coordinate (column) of the top bar.
#     LAYOUT_TOP_BAR_H: Height of the top bar.
#     LAYOUT_TOP_BAR_W: Width of the top bar (terminal width).
#   Requires zsh/curses to be initialized for STTY_COLS.
layout_get_top_bar_dims() {
    LAYOUT_TOP_BAR_Y=0
    LAYOUT_TOP_BAR_X=0
    LAYOUT_TOP_BAR_H=3
    # STTY_COLS is a zsh/curses variable holding terminal width
    LAYOUT_TOP_BAR_W=${STTY_COLS:-80} # Default to 80 if STTY_COLS is not set
}

# Function: layout_draw_top_bar_frame
# Purpose: Draws the frame for the top bar.
# Details:
#   Calls layout_get_top_bar_dims to ensure dimensions are set,
#   then uses render_draw_box to draw the top bar's border.
layout_draw_top_bar_frame() {
    layout_get_top_bar_dims # Ensure dimensions are calculated and set
    render_draw_box "$LAYOUT_TOP_BAR_Y" "$LAYOUT_TOP_BAR_X" "$LAYOUT_TOP_BAR_H" "$LAYOUT_TOP_BAR_W"
}

# Function: layout_draw_top_bar_content
# Purpose: Draws the content inside the top bar, including title and quit button.
# Details:
#   Requires layout_get_top_bar_dims to have been called to set LAYOUT_TOP_BAR_W.
#   Draws a quit button and a centered title.
layout_draw_top_bar_content() {
    layout_get_top_bar_dims # Ensure dimensions like LAYOUT_TOP_BAR_W are available

    # Draw Quit Button (top-left inside the bar)
    # Coordinates are y=1 (middle of top bar height 3: 0,1,2), x=1 (inside left border)
    local quit_button_id="top_bar_quit_button"
    local current_focus_id
    current_focus_id=$(state_get_current_focus_id) # Assumes state.zsh is sourced and function available
    
    local is_quit_button_focused="false"
    if [[ "$current_focus_id" == "$quit_button_id" ]]; then
        is_quit_button_focused="true"
    fi
    widget_draw_button 1 1 "X" "$is_quit_button_focused"

    # Draw Title (centered in the top bar)
    # For now, title is not focusable in the same way, but we could add an ID.
    local title_id="top_bar_title" # Conceptual
    local title="Zif TUI Framework"
    local title_len=${#title}
    local title_x=$(((LAYOUT_TOP_BAR_W - title_len) / 2))

    # Ensure title_x is at least 1 to be within the box
    if (( title_x < 1 )); then
        title_x=1
    fi

    # Coordinates are y=1 (middle of top bar height 3), x calculated above
    render_draw_text 1 "$title_x" "$title"
}
