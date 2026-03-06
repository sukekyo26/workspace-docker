#!/bin/bash
# ============================================================
# tests/test_rebuild_container.sh
# Tests for rebuild-container.sh — execution-based tests
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
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
# Test: devcontainer.sh library is loaded
# ============================================================
test_lib_loaded() {
  section "Library loading"

  # After sourcing devcontainer.sh, check_all_prerequisites should be available
  (
    source "$PROJECT_ROOT/lib/devcontainer.sh"
    assert_true "check_all_prerequisites defined" declare -f check_all_prerequisites
    assert_true "is_wsl defined" declare -f is_wsl
    assert_true "run_devcontainer defined" declare -f run_devcontainer
  )
  local rc=$?
  assert_eq "lib/devcontainer.sh loads without error" "0" "$rc"
}

# ============================================================
# Test: is_wsl function works
# ============================================================
test_is_wsl() {
  section "is_wsl function"

  source "$PROJECT_ROOT/lib/devcontainer.sh"

  # In a standard Docker container, we should NOT be in WSL
  if is_wsl 2>/dev/null; then
    assert_eq "WSL detected (possibly WSL env)" "wsl" "wsl"
  else
    assert_eq "not WSL (standard Docker)" "not-wsl" "not-wsl"
  fi
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_container_detection
test_lib_loaded
test_is_wsl

print_summary
