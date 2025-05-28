# File: button.zsh
# Purpose: UI element for buttons.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Source the renderer for drawing capabilities
# The path is relative to this file's location (src/ui/widgets/button.zsh)
source ../renderer.zsh

# Function: widget_draw_button
# Purpose: Draws a button with given text at a specified position.
# Arguments:
#   $1 (y): The row (Y coordinate) to draw the button.
#   $2 (x): The column (X coordinate) to draw the button.
#   $3 (text): The text label for the button.
#   $4 (is_selected): String "true" or "false". If "true", displays the button as selected.
#                      (Currently, selection is indicated by brackets around the text).
#
# Example: widget_draw_button 10 5 "Submit" "true"
widget_draw_button() {
    local y="$1"
    local x="$2"
    local text="$3"
    local is_selected="$4" # Currently "true" or "false"

    local display_text
    local fg_color bg_color attributes_string

    if [[ "$is_selected" == "true" ]]; then
        # Selected button style: reverse video
        display_text="[ $text ]"
        fg_color="default" 
        bg_color="default" 
        attributes_string="reverse"
    else
        # Normal button style
        display_text="[${text}]"
        fg_color="default"
        bg_color="default"
        attributes_string=""
    fi

    # Call the updated render_draw_text function
    render_draw_text "$y" "$x" "$display_text" "$fg_color" "$bg_color" "$attributes_string"
}
