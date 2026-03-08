#!/bin/bash
# ============================================================
# tests/unit/lib/test_tui.sh
# Tests for lib/tui.sh (non-interactive aspects)
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_tui.sh ]"

# ============================================================
# Test: tui.sh sources successfully and initializes global state
# ============================================================
test_tui_sources_and_initializes() {
  section "tui.sh — sourcing and global state"

  local output
  output=$(bash -c "
    source '$PROJECT_ROOT/lib/tui.sh'
    # TUI_SINGLE_RESULT should be empty string after sourcing
    [[ \"\${TUI_SINGLE_RESULT+set}\" == 'set' ]] && echo 'SINGLE_DECLARED' || echo 'SINGLE_NOT_DECLARED'
    # TUI_MULTI_RESULT should be declared as array
    declare -p TUI_MULTI_RESULT 2>/dev/null | grep -q 'declare' && echo 'MULTI_DECLARED' || echo 'MULTI_NOT_DECLARED'
    # KEY_PRESSED should be empty string
    [[ \"\${KEY_PRESSED+set}\" == 'set' ]] && echo 'KEY_DECLARED' || echo 'KEY_NOT_DECLARED'
  ")

  assert_file_contains "TUI_SINGLE_RESULT is declared" <(echo "$output") "SINGLE_DECLARED"
  assert_file_contains "TUI_MULTI_RESULT is declared"  <(echo "$output") "MULTI_DECLARED"
  assert_file_contains "KEY_PRESSED is declared"       <(echo "$output") "KEY_DECLARED"
}

# ============================================================
# Test: required functions are defined
# ============================================================
test_tui_functions_defined() {
  section "tui.sh — function definitions"

  local funcs=("read_key" "select_single" "select_multi" "tui_cleanup")
  for fn in "${funcs[@]}"; do
    local result
    result=$(bash -c "
      source '$PROJECT_ROOT/lib/tui.sh' 2>/dev/null
      declare -f '$fn' >/dev/null 2>&1 && echo 'DEFINED' || echo 'MISSING'
    ")
    assert_eq "function '$fn' is defined" "DEFINED" "$result"
  done
}

# ============================================================
# Test: tui.sh inherits color variables from colors.sh
# ============================================================
test_tui_inherits_colors() {
  section "tui.sh — inherits colors from colors.sh"

  # NO_COLOR mode: colors from tui.sh context should also be empty
  local output
  output=$(NO_COLOR=1 bash -c "
    source '$PROJECT_ROOT/lib/tui.sh'
    [[ -z \"\${CYAN}\" ]] && echo 'CYAN_EMPTY' || echo 'CYAN_SET'
    [[ -z \"\${NC}\" ]] && echo 'NC_EMPTY' || echo 'NC_SET'
  ")
  assert_file_contains "tui.sh NO_COLOR: CYAN is empty" <(echo "$output") "CYAN_EMPTY"
  assert_file_contains "tui.sh NO_COLOR: NC is empty"   <(echo "$output") "NC_EMPTY"
}

# ============================================================
# Test: select_multi — cancel (q key) returns non-zero and clears result
# ============================================================
test_select_multi_cancel() {
  section "tui.sh — select_multi cancel behaviour"

  # Simulate 'q' key press via stdin redirect
  # /dev/tty is not available in non-interactive context; read_key falls back silently.
  # We can test the return code when /dev/tty read returns empty (CANCEL branch not hit).
  # This is a best-effort check that the function exists and returns a numeric exit code.
  skip_test "select_multi cancel via tty" "requires interactive /dev/tty; tested manually"
}

# ============================================================
# Run
# ============================================================

test_tui_sources_and_initializes
test_tui_functions_defined
test_tui_inherits_colors
test_select_multi_cancel

print_summary
