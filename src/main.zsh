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
zmodload zsh/curses || { echo "Error: zsh/curses module could not be loaded." >&2; return 1; }

# Function to clean up curses environment on exit
cleanup_curses() {
    log_info "Application shutting down..."
    echo "Restoring terminal..."
    zcurses clear stdscr # Clear the screen
    zcurses end          # End curses mode
}

# Setup trap to call cleanup_curses on script exit
trap cleanup_curses EXIT

# Initialize curses environment
zcurses init
log_info "Curses initialized. LINES=$LINES, COLS=$COLS"
# Initialize the screen buffer with terminal dimensions (now uses $LINES and $COLS directly)
screen_buffer_init

# Main event loop for the TUI
main_loop() {
    log_debug "Entered main loop."
    local ZIF_INPUT_CHAR
    local ZIF_INPUT_KEYNAME
    typeset -a ZIF_INPUT_MOUSEDATA # Ensure it's an array for mouse data

    while state_app_is_running; do
        # Clear the current screen buffer for the new frame
        screen_buffer_clear_current

        # Draw the top bar frame
        layout_draw_top_bar_frame

        # Draw the content of the top bar (title and quit button)
        layout_draw_top_bar_content

        # Display current focus for debugging
        local current_focus_for_display
        current_focus_for_display=$(state_get_current_focus_id)
        # Pad with spaces to clear previous longer text. Use specific style.
        render_draw_text 0 20 "Focus: $current_focus_for_display          " "green" "black" ""
        
        # Render the differences from the buffer to the screen
        render_diff_and_draw
        
        # Set input timeout and read input
        zcurses timeout stdscr 100
        zcurses input stdscr ZIF_INPUT_CHAR ZIF_INPUT_KEYNAME ZIF_INPUT_MOUSEDATA

        if [[ -n "$ZIF_INPUT_CHAR" || -n "$ZIF_INPUT_KEYNAME" ]]; then
            log_debug "Input received: char='${ZIF_INPUT_CHAR}', keyname='${ZIF_INPUT_KEYNAME}', mouse_data=(${ZIF_INPUT_MOUSEDATA[*]})_{empty_array_fix}"
            # Pass to event processor
            event_process_keypress "$ZIF_INPUT_CHAR" "$ZIF_INPUT_KEYNAME" "${ZIF_INPUT_MOUSEDATA[@]}"
        else
            # Timeout occurred, no input
            # This is where periodic background tasks could run
            : # No-op or log_debug "Input timeout"
        fi
    done
}

# Start the main TUI loop
main_loop
