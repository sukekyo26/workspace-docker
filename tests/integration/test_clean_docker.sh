#!/bin/bash
# ============================================================
# tests/integration/test_clean_docker.sh
# Tests for clean-docker.sh — execution-based tests
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/.. && pwd)"
# shellcheck source=../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

SCRIPT="$PROJECT_ROOT/clean-docker.sh"

echo ""
echo "[ test_clean_docker.sh ]"

# ============================================================
# Test: Script basics
# ============================================================
test_script_basics() {
  section "Script basics"

  assert_file_exists "clean-docker.sh exists" "$SCRIPT"
  assert_true "script is executable" test -x "$SCRIPT"
  assert_true "bash syntax valid" bash -n "$SCRIPT"
}

# ============================================================
# Test: Container detection blocks execution inside container
# ============================================================
test_container_detection() {
  section "Container detection"

  if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
    local output
    output=$(bash "$SCRIPT" 2>&1 || true)
    assert_file_contains "blocks container execution" \
      <(echo "$output") 'This script cannot be run from inside a container'
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
  assert_file_contains "sources i18n.sh" "$SCRIPT" 'lib/i18n.sh'
  assert_file_contains "sources logging.sh" "$SCRIPT" 'lib/logging.sh'
  assert_file_contains "sources tui.sh" "$SCRIPT" 'lib/tui.sh'
}

# ============================================================
# Test: --lang option support
# ============================================================
test_lang_option() {
  section "--lang option"

  assert_file_contains "pre-parses --lang" "$SCRIPT" 'WORKSPACE_LANG'
  assert_file_contains "handles --lang flag" "$SCRIPT" '"--lang"'
}

# ============================================================
# Test: Docker prune commands
# ============================================================
test_docker_commands() {
  section "Docker prune commands"

  assert_file_contains "container prune" "$SCRIPT" 'docker container prune -f'
  assert_file_contains "builder prune" "$SCRIPT" 'docker builder prune -f'
  assert_file_contains "image prune" "$SCRIPT" 'docker image prune -f'
  assert_file_contains "network prune" "$SCRIPT" 'docker network prune -f'
  assert_file_contains "volume prune" "$SCRIPT" 'docker volume prune -f'
  assert_file_contains "shows disk usage" "$SCRIPT" 'docker system df'
}

# ============================================================
# Run
# ============================================================

test_script_basics
test_container_detection
test_lib_dependencies
test_lang_option
test_docker_commands

print_summary
