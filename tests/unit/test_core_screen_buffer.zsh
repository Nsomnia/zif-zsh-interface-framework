#!/usr/bin/env zsh
# File: tests/unit/test_core_screen_buffer.zsh
# Description: Unit tests for the core screen buffer module.
# Author: Google Jules AI Coder
# License: MIT
# Date: $(date +%Y-%m-%d)

# Note: src/core/screen_buffer.zsh is sourced by the test_runner.
# Assertions are also available from the test_runner.

# Helper function to set LINES and COLS if not set, for test stability
_ensure_screen_dims() {
    : ${LINES:=24} # Default to 24 if LINES is unset or empty
    : ${COLS:=80}  # Default to 80 if COLS is unset or empty
}

test_screen_buffer_set_cell_format() {
    _ensure_screen_dims
    screen_buffer_init # Uses global LINES and COLS

    screen_buffer_set_cell 0 0 "A" "red" "blue" "bold,underline"
    assert_equals "A:red:blue:bold,underline" "${ZIF_SCREEN_CURRENT_BUFFER["0,0"]}" "Cell 0,0 full attributes"

    screen_buffer_set_cell 1 1 "B" # Defaults for color and attributes
    assert_equals "B:default:default:" "${ZIF_SCREEN_CURRENT_BUFFER["1,1"]}" "Cell 1,1 default attributes"

    screen_buffer_set_cell 1 2 "C" "green" # Only fg color specified
    assert_equals "C:green:default:" "${ZIF_SCREEN_CURRENT_BUFFER["1,2"]}" "Cell 1,2 only fg color"

    screen_buffer_set_cell 1 3 "D" "default" "yellow" # Only bg color specified (fg must be given for bg)
    assert_equals "D:default:yellow:" "${ZIF_SCREEN_CURRENT_BUFFER["1,3"]}" "Cell 1,3 only bg color"

    screen_buffer_set_cell 1 4 "E" "default" "default" "reverse" # Only attributes specified
    assert_equals "E:default:default:reverse" "${ZIF_SCREEN_CURRENT_BUFFER["1,4"]}" "Cell 1,4 only attributes"
    
    return 0
}

test_render_diff_and_draw_parsing() {
    # This test simulates the parsing part of render_diff_and_draw without actual zcurses calls.
    _ensure_screen_dims # Needed if screen_buffer_init is called implicitly or for context

    ZIF_SCREEN_CURRENT_BUFFER["0,0"]="X:cyan:magenta:bold,dim"
    # ZIF_SCREEN_PREVIOUS_BUFFER["0,0"]="Y:default:default:" # Not strictly needed for parsing test of current_buffer

    local cell_value="${ZIF_SCREEN_CURRENT_BUFFER["0,0"]}"
    local char fg bg attrs_str
    
    # Using IFS for parsing as done in render_diff_and_draw
    IFS=: read -r char fg bg attrs_str <<< "$cell_value"
            
    assert_equals "X" "$char" "Parsed char should be X"
    assert_equals "cyan" "$fg" "Parsed fg should be cyan"
    assert_equals "magenta" "$bg" "Parsed bg should be magenta"
    assert_equals "bold,dim" "$attrs_str" "Parsed attrs_str should be bold,dim"
            
    # Test splitting of attrs_str
    local -a attrs_array
    attrs_array=(${(s:,:)attrs_str}) # Zsh specific split
    assert_equals "bold" "${attrs_array[1]}" "First attribute should be bold"
    assert_equals "dim" "${attrs_array[2]}" "Second attribute should be dim"
    assert_equals "2" "${#attrs_array[@]}" "Should be 2 attributes"

    # Test parsing of default values with empty attributes string
    ZIF_SCREEN_CURRENT_BUFFER["0,1"]="Y:default:default:"
    cell_value="${ZIF_SCREEN_CURRENT_BUFFER["0,1"]}"
    IFS=: read -r char fg bg attrs_str <<< "$cell_value"
    
    assert_equals "Y" "$char" "Parsed char should be Y (defaults)"
    assert_equals "default" "$fg" "Parsed fg should be default (defaults)"
    assert_equals "default" "$bg" "Parsed bg should be default (defaults)"
    assert_equals "" "$attrs_str" "Parsed attrs_str should be empty (defaults)"
    
    attrs_array=(${(s:,:)attrs_str})
    assert_equals "0" "${#attrs_array[@]}" "Attribute array should be empty for empty attrs_str (defaults)"

    return 0
}

test_screen_buffer_clear_current_format() {
    _ensure_screen_dims
    screen_buffer_init

    # Set a cell with specific attributes
    screen_buffer_set_cell 0 0 "A" "red" "blue" "bold"
    assert_equals "A:red:blue:bold" "${ZIF_SCREEN_CURRENT_BUFFER["0,0"]}" "Cell 0,0 set before clear"

    # Clear the current buffer
    screen_buffer_clear_current

    # Assert that the cell is reset to the default format
    assert_equals " :default:default:" "${ZIF_SCREEN_CURRENT_BUFFER["0,0"]}" "Cell 0,0 after clear should be default"
    
    return 0
}
