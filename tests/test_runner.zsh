#!/usr/bin/env zsh
# File: test_runner.zsh
# Purpose: Runs all unit tests for the Zif Framework.
# Author: Google Jules AI Coder
# License: MIT
# Created: $(date +%Y-%m-%d)

# Enable robust error handling
set -euo pipefail

# --- Configuration ---
# Determine PROJECT_ROOT (assuming this script is in tests/ directory)
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_LIB_DIR="${PROJECT_ROOT}/tests/lib"
UNIT_TEST_DIR="${PROJECT_ROOT}/tests/unit"
SRC_DIR="${PROJECT_ROOT}/src" # For sourcing modules under test

# --- Load Test Libraries ---
source "${TEST_LIB_DIR}/assertions.zsh"

# --- Test Summary ---
typeset -i total_tests=0
typeset -i passed_tests=0
typeset -i failed_tests=0

# --- Test Execution Function ---

# Function: run_test_file
# Purpose: Executes all test functions within a given test file.
# Arguments:
#   $1 (test_file): The path to the test file to execute.
run_test_file() {
    local test_file="$1"
    local test_filename
    test_filename=$(basename "$test_file")

    local module_name_underscored=${test_filename#test_} 
    module_name_underscored=${module_name_underscored%.zsh} 

    local module_path=""
    if [[ -f "${SRC_DIR}/core/${module_name_underscored}.zsh" ]]; then
        module_path="${SRC_DIR}/core/${module_name_underscored}.zsh"
    elif [[ -f "${SRC_DIR}/ui/${module_name_underscored}.zsh" ]]; then
        module_path="${SRC_DIR}/ui/${module_name_underscored}.zsh"
    elif [[ -f "${SRC_DIR}/ui/widgets/${module_name_underscored}.zsh" ]]; then
        module_path="${SRC_DIR}/ui/widgets/${module_name_underscored}.zsh"
    elif [[ -f "${SRC_DIR}/${module_name_underscored}.zsh" ]]; then 
        module_path="${SRC_DIR}/${module_name_underscored}.zsh"
    fi

    echo "\nRunning tests in: $test_filename"
    if [[ -n "$module_path" ]]; then
        echo "  Attempting to test module: $module_path"
    else
        echo "  Warning: Could not automatically determine module for $test_filename."
    fi

    # Source the module and the test file in a subshell to get defined test functions
    # and to isolate any environment changes made by the module/test file setup.
    local test_functions_to_run=()
    _subshell_output=$(
        (
            # Source the module to be tested if found
            if [[ -n "$module_path" && -f "$module_path" ]]; then
                source "$module_path" || {
                    echo "SUBFAIL: Failed to source module '$module_path'." >&2
                    exit 1 
                }
            elif [[ -n "$module_path" ]]; then
                echo "SUBWARN: Module '$module_path' not found." >&2
            fi

            # Source the test file itself
            source "$test_file" || {
                echo "SUBFAIL: Failed to source test file '$test_file'." >&2
                exit 1
            }

            # List functions that start with test_
            for func_name in ${(k)functions}; do
                if [[ "$func_name" == test_* ]]; then
                    echo "$func_name" # Output function names to be captured
                fi
            done
        )
    )
    _subshell_exit_code=$?

    if [[ $_subshell_exit_code -ne 0 ]]; then
        echo "    ERROR: Subshell for sourcing $test_filename failed. Output: $_subshell_output" >&2
        # Consider this a single failed test setup
        total_tests=$((total_tests + 1))
        failed_tests=$((failed_tests + 1))
        return 1
    fi
    
    # Convert the newline-separated list of functions from subshell output to an array
    test_functions_to_run=(${(f)_subshell_output})

    if [[ ${#test_functions_to_run[@]} -eq 0 ]]; then
        echo "  No test functions (test_*) found in $test_filename."
        return 0
    fi

    # Now, run these identified test functions in the current shell context
    # This allows them to modify global counters and use global assertions.
    # The module itself is NOT re-sourced here to avoid duplicate sourcing effects if it has global state setup.
    # This assumes test functions are self-contained or rely on module state already set up
    # (which is tricky if module setup was in subshell, but test functions expect it globally).
    # This is a common challenge: balancing isolation with the ability for tests to interact with the runner.
    # For simplicity, we assume test functions are defined by the subshell sourcing and are now callable.
    
    # Re-source the test file in the current shell to make test functions available.
    # This is necessary because functions defined in a subshell are not available to the parent.
    # The module is NOT re-sourced to avoid side effects if it modifies global state on source.
    # This means the test functions must be written to work even if the module was only fully "active"
    # in the subshell. This is a limitation of this runner design.
    source "$test_file" || {
        echo "    ERROR: Failed to re-source test file '$test_file' in main shell context." >&2
        total_tests=$((total_tests + ${#test_functions_to_run[@]})) # Count all potential tests as failed
        failed_tests=$((failed_tests + ${#test_functions_to_run[@]}))
        return 1
    }


    local func_name
    for func_name in $test_functions_to_run; do
        total_tests=$((total_tests + 1))
        echo "  -> Running test: $func_name"
        if $func_name; then # Execute the test function
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
    done
}


# --- Main Execution ---
echo "=============================="
echo "Zif Framework Test Suite"
echo "=============================="
echo "Searching for tests in: $UNIT_TEST_DIR"

if ! compgen -G "${UNIT_TEST_DIR}/test_*.zsh" > /dev/null; then
    echo "No test files found matching 'test_*.zsh' in $UNIT_TEST_DIR"
else
    for test_file_path in ${UNIT_TEST_DIR}/test_*.zsh; do
        if [[ -f "$test_file_path" ]]; then
            run_test_file "$test_file_path"
        fi
    done
fi

echo "\n--- Test Summary ---"
echo "Total tests run: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"

if (( failed_tests == 0 && total_tests > 0 )); then
    echo "\nAll tests passed!"
    exit 0
elif (( total_tests == 0 )); then
    echo "\nNo tests were run."
    # Decide if no tests found is an error or success. For CI, often an error.
    # For now, let's say it's a non-failure exit.
    exit 0 
else
    echo "\nSome tests failed."
    exit 1
fi
