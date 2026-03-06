#!/bin/bash
# ============================================================
# tests/integration/test_clean_volumes.sh
# Tests for clean-volumes.sh — execution-based tests
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/clean-volumes.sh"

echo ""
echo "[ test_clean_volumes.sh ]"

# ============================================================
# Test: Script basics
# ============================================================
test_script_basics() {
    section "Script basics"

    assert_file_exists "clean-volumes.sh exists" "$SCRIPT"
    assert_true "script is executable" test -x "$SCRIPT"
    assert_true "bash syntax valid" bash -n "$SCRIPT"
}

# ============================================================
# Test: Container detection blocks execution inside container
# ============================================================
test_container_detection() {
    section "Container detection"

    # We ARE inside a container, so the script should fail with error
    if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
        local output
        output=$(bash "$SCRIPT" 2>&1 || true)
        assert_file_contains "blocks container execution" \
            <(echo "$output") 'コンテナ内からは実行できません'
    else
        skip_test "container detection" "not running inside container"
    fi
}

# ============================================================
# Test: Required library sourcing
# ============================================================
test_lib_dependencies() {
    section "Library dependencies"

    assert_file_contains "sources colors.sh" "$SCRIPT" 'lib/colors.sh'
    assert_file_contains "sources utils.sh" "$SCRIPT" 'lib/utils.sh'
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_container_detection
test_lib_dependencies

print_summary
