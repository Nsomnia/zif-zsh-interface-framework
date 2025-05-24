#!/usr/bin/env zsh
# File: tests/unit/test_core_state.zsh
# Description: Unit tests for the core state management module.
# Author: Google Jules AI Coder
# License: MIT
# Date: $(date +%Y-%m-%d)

# Note: src/core/state.zsh is sourced by the test_runner in a subshell
# where ZIF_STATE is initialized. Each test function also runs in a subshell.

test_initial_state_app_should_run() {
    assert_equals "true" "$(state_get "APP_SHOULD_RUN")" "APP_SHOULD_RUN should be true initially"
    return 0
}

test_initial_state_current_view() {
    assert_equals "main_menu" "$(state_get "CURRENT_VIEW")" "CURRENT_VIEW should be main_menu initially"
    return 0
}

test_state_set_and_get() {
    state_set "my_key" "my_value"
    assert_equals "my_value" "$(state_get "my_key")" "Should retrieve the set value"
    
    state_set "another_key" "another_value123"
    assert_equals "another_value123" "$(state_get "another_key")" "Should retrieve another complex value"
    return 0
}

test_state_app_is_running() {
    state_set "APP_SHOULD_RUN" "true"
    assert_true "$(state_app_is_running)" "state_app_is_running should return true (0)"
    
    state_set "APP_SHOULD_RUN" "false"
    assert_false "$(state_app_is_running)" "state_app_is_running should return false (1)"
    return 0
}

test_state_quit_app() {
    state_quit_app
    assert_equals "false" "$(state_get "APP_SHOULD_RUN")" "APP_SHOULD_RUN should be false after state_quit_app"
    return 0
}
