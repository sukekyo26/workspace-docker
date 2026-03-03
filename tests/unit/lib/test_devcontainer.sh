#!/bin/bash
# ============================================================
# tests/unit/lib/test_devcontainer.sh
# Tests for lib/devcontainer.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_devcontainer.sh ]"

source "$PROJECT_ROOT/lib/devcontainer.sh"

# ============================================================
# Test: devcontainer.sh function definitions and execution
# ============================================================
test_devcontainer_functions() {
    section "devcontainer.sh functions"

    # Functions are defined and callable
    assert_true "check_docker is a function" declare -f check_docker
    assert_true "check_devcontainer_cli is a function" declare -f check_devcontainer_cli
    assert_true "check_all_prerequisites is a function" declare -f check_all_prerequisites
    assert_true "is_wsl is a function" declare -f is_wsl
    assert_true "run_devcontainer is a function" declare -f run_devcontainer

    # is_wsl returns meaningful result (not error)
    is_wsl 2>/dev/null
    local wsl_rc=$?
    assert_true "is_wsl returns 0 or 1" test "$wsl_rc" -le 1

    # check_docker runs (Docker available in this container)
    if command -v docker &>/dev/null; then
        assert_true "check_docker succeeds" check_docker
    else
        skip_test "check_docker execution" "docker not installed"
    fi
}

# ============================================================
# Run
# ============================================================

test_devcontainer_functions

print_summary
