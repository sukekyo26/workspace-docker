#!/bin/bash
# ============================================================
# tests/unit/lib/test_colors.sh
# Tests for lib/colors.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_colors.sh ]"

# ============================================================
# Test: NO_COLOR mode — all variables must be empty
# ============================================================
test_no_color_mode() {
  section "colors.sh — NO_COLOR mode"

  # Source in a subshell with NO_COLOR set to avoid polluting the current shell
  local output
  output=$(NO_COLOR=1 bash -c "
    source '$PROJECT_ROOT/lib/colors.sh'
    echo \"RED=\${RED}\"
    echo \"GREEN=\${GREEN}\"
    echo \"CYAN=\${CYAN}\"
    echo \"YELLOW=\${YELLOW}\"
    echo \"BOLD=\${BOLD}\"
    echo \"DIM=\${DIM}\"
    echo \"NC=\${NC}\"
  ")

  assert_eq "NO_COLOR: RED is empty"    "RED="    "$(echo "$output" | grep '^RED=')"
  assert_eq "NO_COLOR: GREEN is empty"  "GREEN="  "$(echo "$output" | grep '^GREEN=')"
  assert_eq "NO_COLOR: CYAN is empty"   "CYAN="   "$(echo "$output" | grep '^CYAN=')"
  assert_eq "NO_COLOR: YELLOW is empty" "YELLOW=" "$(echo "$output" | grep '^YELLOW=')"
  assert_eq "NO_COLOR: BOLD is empty"   "BOLD="   "$(echo "$output" | grep '^BOLD=')"
  assert_eq "NO_COLOR: DIM is empty"    "DIM="    "$(echo "$output" | grep '^DIM=')"
  assert_eq "NO_COLOR: NC is empty"     "NC="     "$(echo "$output" | grep '^NC=')"
}

# ============================================================
# Test: color mode — escape sequences must be set
# ============================================================
test_color_mode() {
  section "colors.sh — color mode (without NO_COLOR)"

  local output
  output=$(bash -c "
    unset NO_COLOR
    source '$PROJECT_ROOT/lib/colors.sh'
    [[ -n \"\${RED}\" ]] && echo 'RED_SET' || echo 'RED_EMPTY'
    [[ -n \"\${GREEN}\" ]] && echo 'GREEN_SET' || echo 'GREEN_EMPTY'
    [[ -n \"\${CYAN}\" ]] && echo 'CYAN_SET' || echo 'CYAN_EMPTY'
    [[ -n \"\${YELLOW}\" ]] && echo 'YELLOW_SET' || echo 'YELLOW_EMPTY'
    [[ -n \"\${BOLD}\" ]] && echo 'BOLD_SET' || echo 'BOLD_EMPTY'
    [[ -n \"\${DIM}\" ]] && echo 'DIM_SET' || echo 'DIM_EMPTY'
    [[ -n \"\${NC}\" ]] && echo 'NC_SET' || echo 'NC_EMPTY'
  ")

  assert_file_contains "color mode: RED is set"    <(echo "$output") "RED_SET"
  assert_file_contains "color mode: GREEN is set"  <(echo "$output") "GREEN_SET"
  assert_file_contains "color mode: CYAN is set"   <(echo "$output") "CYAN_SET"
  assert_file_contains "color mode: YELLOW is set" <(echo "$output") "YELLOW_SET"
  assert_file_contains "color mode: BOLD is set"   <(echo "$output") "BOLD_SET"
  assert_file_contains "color mode: DIM is set"    <(echo "$output") "DIM_SET"
  assert_file_contains "color mode: NC is set"     <(echo "$output") "NC_SET"
}

# ============================================================
# Test: escape sequence format
# ============================================================
test_escape_sequence_format() {
  section "colors.sh — escape sequence format"

  local output
  output=$(bash -c "
    unset NO_COLOR
    source '$PROJECT_ROOT/lib/colors.sh'
    # Variables should contain ANSI escape prefix \\033[
    [[ \"\${RED}\" == *'\\033['* ]] && echo 'RED_ANSI' || echo 'RED_NOT_ANSI'
    [[ \"\${GREEN}\" == *'\\033['* ]] && echo 'GREEN_ANSI' || echo 'GREEN_NOT_ANSI'
    [[ \"\${NC}\" == *'\\033['* ]] && echo 'NC_ANSI' || echo 'NC_NOT_ANSI'
    # BOLD uses \\033[1 (not \\033[0)
    [[ \"\${BOLD}\" == *'\\033['* ]] && echo 'BOLD_ANSI' || echo 'BOLD_NOT_ANSI'
  ")

  assert_file_contains "RED contains ANSI escape"   <(echo "$output") "RED_ANSI"
  assert_file_contains "GREEN contains ANSI escape" <(echo "$output") "GREEN_ANSI"
  assert_file_contains "NC contains ANSI escape"    <(echo "$output") "NC_ANSI"
  assert_file_contains "BOLD contains ANSI escape"  <(echo "$output") "BOLD_ANSI"
}

# ============================================================
# Run
# ============================================================

test_no_color_mode
test_color_mode
test_escape_sequence_format

print_summary
