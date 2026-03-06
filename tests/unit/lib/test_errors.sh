#!/bin/bash
# ============================================================
# tests/unit/lib/test_errors.sh
# Tests for lib/errors.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_errors.sh ]"

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
# Run
# ============================================================

test_error_functions

print_summary
