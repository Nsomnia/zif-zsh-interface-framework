#!/usr/bin/env zsh
# File: tests/unit/test_core_logging.zsh
# Description: Unit tests for the core logging module.
# Author: Google Jules AI Coder
# License: MIT
# Date: $(date +%Y-%m-%d)

# Note: src/core/logging.zsh is sourced by the test_runner.
# These tests will primarily check if log commands run without error
# and if log level filtering logic is sound. Checking file content is more complex
# for unit tests and might be better for integration tests.

# Mock mkdir and date for controlled testing if possible, or test behavior.
# For now, let's assume ZIF_LOG_FILE is writable.

test_logging_get_level_value() {
    assert_equals "0" "$(logging_get_level_value "DEBUG")" "DEBUG level value should be 0"
    assert_equals "1" "$(logging_get_level_value "INFO")" "INFO level value should be 1"
    assert_equals "2" "$(logging_get_level_value "WARN")" "WARN level value should be 2"
    assert_equals "3" "$(logging_get_level_value "ERROR")" "ERROR level value should be 3"
    assert_equals "4" "$(logging_get_level_value "CRITICAL")" "CRITICAL level value should be 4"
    # The task spec for this test expects unknown levels to default to INFO's value (1).
    # The current logging_get_level_value in src/core/logging.zsh is:
    # echo "${ZIF_LOG_LEVEL_VALUES[$level_name]:-99}" 
    # This means it returns 99 for unknown levels, not 1.
    # To pass this test as written, logging_get_level_value would need to be changed.
    # Or, the test should be changed to expect 99.
    # Given the instruction is to populate with *this* content, I will use it as is.
    # This test will likely fail with the current implementation of logging_get_level_value.
    assert_equals "1" "$(logging_get_level_value "UNKNOWN_LEVEL")" "Unknown log level should default to INFO (1)"
    return 0
}

test_log_message_filtering() {
    # Save old global ZIF_LOG_LEVEL and ZIF_LOG_FILE
    # The $ and \ are important here to correctly capture the *names* of the globals
    # for later restoration, not their current values, if we were doing complex eval.
    # However, for simple assignment, direct value is fine if we ensure scope.
    # The test runner runs each test function in its own subshell, so globals are tricky.
    # For this test to correctly modify and restore ZIF_LOG_LEVEL and ZIF_LOG_FILE
    # *globally* for the helper functions to see, these modifications must happen
    # in a scope that affects the sourced logging functions.
    # The test runner's current design (sourcing module then test file in subshell,
    # then test functions in main shell) means ZIF_LOG_LEVEL set here might not be seen by log_message
    # if it's re-initialized from a global scope.
    # However, since ZIF_LOG_LEVEL is a global in logging.zsh, direct modification here
    # *should* affect it for the duration of this test function call.

    local ZIF_LOG_LEVEL_OLD="$ZIF_LOG_LEVEL"
    local ZIF_LOG_FILE_OLD="$ZIF_LOG_FILE"
    
    ZIF_LOG_LEVEL="INFO" # Set log level high enough that DEBUG messages are skipped
    
    # Create a temporary log file for this test
    # Ensure mktemp is available and works.
    local ZIF_LOG_FILE_TEMP
    ZIF_LOG_FILE_TEMP=$(mktemp)
    if [[ -z "$ZIF_LOG_FILE_TEMP" ]]; then
        echo "    FAIL: mktemp failed. Cannot run test_log_message_filtering." >&2
        # Restore globals just in case, though test will fail
        ZIF_LOG_LEVEL="$ZIF_LOG_LEVEL_OLD"
        ZIF_LOG_FILE="$ZIF_LOG_FILE_OLD"
        return 1 # Indicate failure
    fi
    ZIF_LOG_FILE="$ZIF_LOG_FILE_TEMP" # Override global log file path for this test

    # Test Case 1: Log level INFO, message DEBUG (should not log)
    log_message "DEBUG" "This is a debug message."
    # Assert that the log file is empty after this
    # `! -s` checks if file is empty (size is zero)
    assert_true "[[ ! -s \"$ZIF_LOG_FILE\" ]]" "Log file should be empty when DEBUG msg logged at INFO level."

    # Test Case 2: Log level INFO, message INFO (should log)
    log_message "INFO" "This is an info message."
    # Check if the temp log file now contains "This is an info message."
    assert_true "grep -q \"This is an info message.\" \"$ZIF_LOG_FILE\"" "Log file should contain INFO message when level is INFO."
    
    # Clear the log file for the next test by truncating it
    :> "$ZIF_LOG_FILE"

    # Test Case 3: Log level DEBUG, message DEBUG (should log)
    ZIF_LOG_LEVEL="DEBUG" 
    log_message "DEBUG" "Another debug message."
    assert_true "grep -q \"Another debug message.\" \"$ZIF_LOG_FILE\"" "Log file should contain DEBUG message when level is DEBUG."

    # Cleanup
    rm -f "$ZIF_LOG_FILE_TEMP"
    ZIF_LOG_LEVEL="$ZIF_LOG_LEVEL_OLD" # Restore old level
    ZIF_LOG_FILE="$ZIF_LOG_FILE_OLD"   # Restore old log file path
    return 0
}

test_helper_log_functions_run() {
    # Simply test that these functions can be called without error and return 0
    # The `assert_true "$(command && echo 0)"` pattern is a bit fragile.
    # A better way is to call the command and then check $? if we want to assert success.
    # However, the test runner itself checks the exit status of test_ functions.
    # If `set -e` is active (it is, via `set -euo pipefail` in runner), any command failure would stop the script.
    # So, just calling them is a test of "does not fail".
    # To make them fit `assert_true` which expects a command string that evaluates to true (exit 0):
    # We can run the command and check its exit status.
    # `assert_true "log_debug 'Debug test'; exit \$?"` is not quite right.
    # The pattern `command && echo 0` results in an empty string if command fails, or "0" if success.
    # `assert_true` then checks if this string "0" (when command succeeds) is a successful command itself.
    # This is a bit convoluted.
    # Given the current `assert_true` expects a command string:
    # A command like `(log_debug "Debug test" && true)` would be a valid command string for `assert_true`.

    # Redirect actual log output to /dev/null for these calls to keep test output clean.
    local ZIF_LOG_FILE_OLD="$ZIF_LOG_FILE"
    ZIF_LOG_FILE="/dev/null"

    assert_true "(log_debug 'Debug test' && true)" "log_debug should run successfully"
    assert_true "(log_info 'Info test' && true)" "log_info should run successfully"
    assert_true "(log_warn 'Warn test' && true)" "log_warn should run successfully"
    assert_true "(log_error 'Error test' && true)" "log_error should run successfully"
    assert_true "(log_critical 'Critical test' && true)" "log_critical should run successfully"
    
    ZIF_LOG_FILE="$ZIF_LOG_FILE_OLD" # Restore
    return 0
}
```
