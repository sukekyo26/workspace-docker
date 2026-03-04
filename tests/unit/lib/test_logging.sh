#!/bin/bash
# ============================================================
# tests/unit/lib/test_logging.sh
# Tests for lib/logging.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_logging.sh ]"

source "$PROJECT_ROOT/lib/logging.sh"

# ============================================================
# Test: logging functions
# ============================================================
test_error_functions() {
    section "Error/logging functions"

    # Test error output goes to stderr
    local output
    output=$(error "test error" 2>&1)
    assert_file_contains "error() outputs ERROR:" <(echo "$output") "ERROR:"

    output=$(warn "test warning" 2>&1)
    assert_file_contains "warn() outputs WARNING:" <(echo "$output") "WARNING:"

    output=$(info "test info" 2>&1)
    assert_file_contains "info() outputs INFO:" <(echo "$output") "INFO:"

    output=$(success "test success" 2>&1)
    assert_true "success() produces output" test -n "$output"
}

# ============================================================
# Test: die and die_with_hint (must run in subshell)
# ============================================================
test_die_functions() {
    section "die / die_with_hint"

    # die exits with code 1
    local output exit_code
    output=$( (die "fatal error") 2>&1 ) || exit_code=$?
    assert_eq "die exits with code 1" "$exit_code" "1"
    assert_file_contains "die outputs ERROR:" <(echo "$output") "ERROR:"
    assert_file_contains "die outputs message" <(echo "$output") "fatal error"

    # die_with_hint exits with code 1 and shows hint
    output=$( (die_with_hint "something broke" "try this fix") 2>&1 ) || exit_code=$?
    assert_eq "die_with_hint exits with code 1" "$exit_code" "1"
    assert_file_contains "die_with_hint outputs ERROR:" <(echo "$output") "ERROR:"
    assert_file_contains "die_with_hint outputs HINT:" <(echo "$output") "HINT:"
    assert_file_contains "die_with_hint outputs hint text" <(echo "$output") "try this fix"
}

# ============================================================
# Run
# ============================================================

test_error_functions
test_die_functions

print_summary
