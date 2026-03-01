#!/bin/bash
# ============================================================
# tests/test_rebuild_container.sh
# Tests for rebuild-container.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/rebuild-container.sh"

echo ""
echo "[ test_rebuild_container.sh ]"

# ============================================================
# Test: Script basics
# ============================================================
test_script_basics() {
    section "Script basics"

    assert_file_exists "rebuild-container.sh exists" "$SCRIPT"
    assert_true "script is executable" test -x "$SCRIPT"
    assert_true "bash syntax valid" bash -n "$SCRIPT"
}

# ============================================================
# Test: Container detection
# ============================================================
test_container_detection() {
    section "Container detection"

    assert_file_contains "checks /.dockerenv" "$SCRIPT" '/.dockerenv'
    assert_file_contains "checks /proc/1/cgroup" "$SCRIPT" '/proc/1/cgroup'
    assert_file_contains "blocks container execution" "$SCRIPT" 'コンテナ内からは実行できません'
}

# ============================================================
# Test: Prerequisites checks
# ============================================================
test_prerequisites() {
    section "Prerequisites checks"

    assert_file_contains "checks Docker (via lib)" "$SCRIPT" 'check_all_prerequisites\|lib/devcontainer.sh'
    assert_file_contains "sources lib/devcontainer.sh" "$SCRIPT" 'lib/devcontainer.sh'
    assert_file_contains "calls check_all_prerequisites" "$SCRIPT" 'check_all_prerequisites'
    assert_file_contains "checks devcontainer CLI (via lib)" "$SCRIPT" 'check_all_prerequisites\|lib/devcontainer.sh'
    assert_file_contains "checks devcontainer.json (via lib)" "$SCRIPT" 'check_all_prerequisites\|lib/devcontainer.sh'
}

# ============================================================
# Test: WSL support
# ============================================================
test_wsl_support() {
    section "WSL support"

    assert_file_contains "uses run_devcontainer wrapper" "$SCRIPT" 'run_devcontainer'
}

# ============================================================
# Test: Rebuild confirmation
# ============================================================
test_confirmation() {
    section "Rebuild confirmation"

    assert_file_contains "asks for confirmation" "$SCRIPT" 'リビルドを実行しますか'
    assert_file_contains "supports cancel" "$SCRIPT" 'キャンセルしました'
}

# ============================================================
# Test: devcontainer rebuild commands
# ============================================================
test_rebuild_commands() {
    section "Rebuild commands"

    assert_file_contains "uses devcontainer up" "$SCRIPT" 'devcontainer up'
    assert_file_contains "uses --build-no-cache" "$SCRIPT" '\-\-build-no-cache'
    assert_file_contains "uses --remove-existing-container" "$SCRIPT" '\-\-remove-existing-container'
}

# ============================================================
# Test: Image info display
# ============================================================
test_image_info() {
    section "Image info display"

    assert_file_contains "reads service name from .env" "$SCRIPT" 'CONTAINER_SERVICE_NAME'
    assert_file_contains "constructs image name" "$SCRIPT" 'IMAGE_NAME='
    assert_file_contains "shows image creation date" "$SCRIPT" 'イメージ'
}

# ============================================================
# Test: Completion message
# ============================================================
test_completion_message() {
    section "Completion message"

    assert_file_contains "shows Reopen in Container guidance" "$SCRIPT" 'Reopen in Container'
}

# ============================================================
# Test: shellcheck
# ============================================================
test_shellcheck() {
    section "shellcheck"

    if ! command -v shellcheck &>/dev/null; then
        skip_test "shellcheck rebuild-container.sh" "shellcheck not installed"
        return
    fi

    local result
    result=$(shellcheck -S error "$SCRIPT" 2>&1 || true)
    if [[ -z "$result" ]]; then
        assert_eq "shellcheck passes (errors only)" "0" "0"
    else
        echo "$result" | head -10 | sed 's/^/      /'
        assert_eq "shellcheck passes (errors only)" "0" "1"
    fi
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_container_detection
test_prerequisites
test_wsl_support
test_confirmation
test_rebuild_commands
test_image_info
test_completion_message
test_shellcheck

print_summary
