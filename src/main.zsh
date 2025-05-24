#!/usr/bin/env zsh
# File: main.zsh
# Purpose: Main entry point for the Zif Framework application, TUI initialization, and event loop.
# Author: Zif Framework (AI Generated)
# License: MIT
# Created: $(date +%Y-%m-%d)

# Enable robust error handling
set -euo pipefail

# Source the state management script
source "$(dirname "$0")/core/state.zsh"

# Source the event management script
source "$(dirname "$0")/core/events.zsh"

# Source the UI layout script (which sources renderer.zsh)
source "$(dirname "$0")/ui/layout.zsh"

# Source the logging utility
source "$(dirname "$0")/core/logging.zsh"

# Source the screen buffer utility
source "$(dirname "$0")/core/screen_buffer.zsh"

# Load zsh/curses module for TUI capabilities
zmodload zsh/curses

# Function to clean up curses environment on exit
cleanup_curses() {
    log_info "Application shutting down..."
    echo "Restoring terminal..."
    zcurses_clear # Ensure terminal is cleared on exit
    zcurses_exit
}

# Setup trap to call cleanup_curses on script exit
trap cleanup_curses EXIT

# Initialize curses environment
zcurses_init
zcurses_mouse_on # Enable mouse events
log_info "Application starting..."
log_info "Mouse support enabled."
# Initialize the screen buffer with terminal dimensions
screen_buffer_init "$STTY_ROWS" "$STTY_COLS"

# Main event loop for the TUI
main_loop() {
    log_debug "Entered main loop."
    local char
    while state_app_is_running; do
        # Clear the current screen buffer for the new frame
        screen_buffer_clear_current

        # Draw the top bar frame
        layout_draw_top_bar_frame

        # Draw the content of the top bar (title and quit button)
        layout_draw_top_bar_content

        # Display current focus for debugging (will be changed to use buffer later)
        local current_focus_for_display
        current_focus_for_display=$(state_get_current_focus_id)
        render_draw_text 0 20 "Focus: $current_focus_for_display          " # Pad with spaces to clear previous longer text
        
        # Render the differences from the buffer to the screen
        render_diff_and_draw

        # Get character input with a 100ms timeout
        # This allows the loop to iterate for periodic updates/animations in the future.
        char=$(zcurses_getch -t 100)

        if [[ -n "$char" ]]; then
            log_debug "Key pressed: $char"
            # Process the keypress event only if a key was actually pressed
            event_process_keypress "$char"
        else
            # Timeout occurred, no key pressed.
            # Future periodic tasks could be run here.
            : # Placeholder for now
        fi
    done
}

# Start the main TUI loop
main_loop
