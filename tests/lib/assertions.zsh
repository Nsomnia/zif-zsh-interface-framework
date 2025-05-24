# File: assertions.zsh
# Purpose: Common assertion functions for Zif tests.
# Author: Google Jules AI Coder
# License: MIT
# Created: $(date +%Y-%m-%d)

# Function: assert_equals
# Purpose: Asserts that two string values are equal.
# Arguments:
#   $1 (expected): The expected string value.
#   $2 (actual): The actual string value.
#   $3 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Expected: '$expected', Actual: '$actual'" >&2
        return 1
    fi
}

# Function: assert_not_equals
# Purpose: Asserts that two string values are not equal.
# Arguments:
#   $1 (unexpected): The unexpected string value.
#   $2 (actual): The actual string value.
#   $3 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$unexpected" != "$actual" ]]; then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Unexpected: '$unexpected', Actual: '$actual'" >&2
        return 1
    fi
}

# Function: assert_true
# Purpose: Asserts that a condition is true (exit code 0).
# Arguments:
#   $1 (condition_command): A command or expression that evaluates to true (exit code 0) or false (non-zero exit code).
#   $2 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_true() {
    local condition_command="$1"
    local message="$2"
    # Execute the command string. Note: this is a simple version.
    # For more complex commands, consider using eval or a function.
    if (eval "$condition_command"); then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Condition was false (non-zero exit code)." >&2
        return 1
    fi
}

# Function: assert_false
# Purpose: Asserts that a condition is false (non-zero exit code).
# Arguments:
#   $1 (condition_command): A command or expression that evaluates to true (exit code 0) or false (non-zero exit code).
#   $2 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_false() {
    local condition_command="$1"
    local message="$2"
    if !(eval "$condition_command"); then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Condition was true (exit code 0)." >&2
        return 1
    fi
}

# Function: assert_empty
# Purpose: Asserts that a string is empty.
# Arguments:
#   $1 (value): The string value to check.
#   $2 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_empty() {
    local value="$1"
    local message="$2"
    if [[ -z "$value" ]]; then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Expected empty, but was: '$value'" >&2
        return 1
    fi
}

# Function: assert_not_empty
# Purpose: Asserts that a string is not empty.
# Arguments:
#   $1 (value): The string value to check.
#   $2 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_not_empty() {
    local value="$1"
    local message="$2"
    if [[ -n "$value" ]]; then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Expected not empty, but was empty." >&2
        return 1
    fi
}

# Function: assert_array_contains
# Purpose: Asserts that an array contains a specific element.
# Arguments:
#   $1 (element): The element to search for.
#   $2 (array_name_str): The string name of the array (e.g., "my_array").
#   $3 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_array_contains() {
    local element="$1"
    local array_name_str="$2"
    local message="$3"
    local -a target_array # Declare as local array
    # Indirectly expand the array name to its elements
    eval "target_array=(\"\${(@)${array_name_str}[@]}\")"

    if (($target_array[(Ie)$element])); then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Element '$element' not found in array '${array_name_str}'." >&2
        return 1
    fi
}

# Function: assert_exit_code
# Purpose: Asserts that a command exits with a specific code.
# Arguments:
#   $1 (expected_code): The expected exit code.
#   $2 (command_string): The command to execute.
#   $3 (message): The message to display on failure.
# Returns: 0 on success, 1 on failure.
assert_exit_code() {
    local expected_code="$1"
    local command_string="$2"
    local message="$3"
    local actual_code

    (eval "$command_string")
    actual_code=$?

    if [[ "$actual_code" -eq "$expected_code" ]]; then
        echo "    PASS: $message"
        return 0
    else
        echo "    FAIL: $message. Expected exit code: '$expected_code', Actual: '$actual_code' for command: '$command_string'" >&2
        return 1
    fi
}
