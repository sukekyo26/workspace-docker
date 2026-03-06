#!/bin/bash
# ============================================================
# tests/unit/lib/test_safe_eval.sh
# Security tests for _parse_toml_output whitelist mechanism
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_safe_eval.sh ]"

# Source the module under test
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/utils.sh"

# ============================================================
# Test: Allowed variables are accepted
# ============================================================
test_allowed_variables() {
  section "Allowed variables accepted"

  local output=$'S:MY_VAR=hello\nS:MY_OTHER=world'
  _parse_toml_output "$output" MY_VAR MY_OTHER
  assert_eq "allowed MY_VAR" "hello" "$MY_VAR"
  assert_eq "allowed MY_OTHER" "world" "$MY_OTHER"
}

# ============================================================
# Test: Unknown variable is rejected
# ============================================================
test_unknown_variable_rejected() {
  section "Unknown variable rejected"

  local output=$'S:ALLOWED=ok\nS:UNKNOWN=bad'
  local result
  result=$(_parse_toml_output "$output" ALLOWED 2>&1) || true
  assert_true "rejects unknown variable" test -n "$(echo "$result" | grep "Unexpected variable")"
}

# ============================================================
# Test: Invalid variable name is rejected
# ============================================================
test_invalid_variable_name() {
  section "Invalid variable name rejected"

  # Variable name with command substitution
  local result
  # shellcheck disable=SC2016
  result=$(_parse_toml_output 'S:$(whoami)=pwned' '$(whoami)' 2>&1) || true
  assert_true "rejects command substitution in name" test -n "$(echo "$result" | grep "Invalid variable name")"

  # Variable name with spaces
  result=$(_parse_toml_output 'S:MY VAR=value' 'MY VAR' 2>&1) || true
  assert_true "rejects spaces in name" test -n "$(echo "$result" | grep "Invalid variable name")"

  # Variable name starting with number
  result=$(_parse_toml_output 'S:1VAR=value' '1VAR' 2>&1) || true
  assert_true "rejects number-prefixed name" test -n "$(echo "$result" | grep "Invalid variable name")"

  # Variable name with semicolon (injection attempt)
  result=$(_parse_toml_output 'S:VAR;rm -rf /=value' 'VAR;rm -rf /' 2>&1) || true
  assert_true "rejects semicolon injection" test -n "$(echo "$result" | grep "Invalid variable name")"
}

# ============================================================
# Test: Empty input is handled
# ============================================================
test_empty_input() {
  section "Empty input handled"

  _parse_toml_output "" ANYTHING
  assert_eq "empty input succeeds" "0" "$?"
}

# ============================================================
# Test: Backtick injection in variable name
# ============================================================
test_backtick_injection() {
  section "Backtick injection"

  local result
  # shellcheck disable=SC2016
  result=$(_parse_toml_output 'S:`whoami`=pwned' '`whoami`' 2>&1) || true
  assert_true "rejects backtick in name" test -n "$(echo "$result" | grep "Invalid variable name")"
}

# ============================================================
# Test: Whitelist is strict (exact match)
# ============================================================
test_whitelist_exact_match() {
  section "Whitelist exact match"

  # Prefix match should NOT work
  local result
  result=$(_parse_toml_output 'S:MY_VAR_EXTRA=bad' MY_VAR 2>&1) || true
  assert_true "rejects prefix match" test -n "$(echo "$result" | grep "Unexpected variable")"
}

# ============================================================
# Test: Unknown type prefix is rejected
# ============================================================
test_unknown_type_prefix() {
  section "Unknown type prefix rejected"

  local result
  result=$(_parse_toml_output 'X:MY_VAR=bad' MY_VAR 2>&1) || true
  assert_true "rejects unknown type prefix" test -n "$(echo "$result" | grep "Unknown type prefix")"
}

# ============================================================
# Test: Array parsing
# ============================================================
test_array_parsing() {
  section "Array parsing"

  # Array with elements (using unit separator \x1f)
  local output
  output=$(printf 'A:MY_ARR=one\x1ftwo\x1fthree')
  _parse_toml_output "$output" MY_ARR
  assert_eq "array count" "3" "${#MY_ARR[@]}"
  assert_eq "array[0]" "one" "${MY_ARR[0]}"
  assert_eq "array[1]" "two" "${MY_ARR[1]}"
  assert_eq "array[2]" "three" "${MY_ARR[2]}"

  # Empty array
  _parse_toml_output "A:EMPTY_ARR=" EMPTY_ARR
  assert_eq "empty array count" "0" "${#EMPTY_ARR[@]}"
}

# ============================================================
# Test: Escape sequence decoding
# ============================================================
test_escape_decoding() {
  section "Escape sequence decoding"

  # Scalar with encoded newline
  _parse_toml_output 'S:MULTI_LINE=line1\nline2' MULTI_LINE
  local expected=$'line1\nline2'
  assert_eq "newline decoded" "$expected" "$MULTI_LINE"

  # Scalar with encoded backslash (encode_value: \ → \\)
  _parse_toml_output 'S:BS_VAR=path\\to' BS_VAR
  assert_eq "backslash decoded" 'path\to' "$BS_VAR"

  # Scalar with encoded tab (encode_value: tab → \t)
  _parse_toml_output 'S:TAB_VAR=col1\tcol2' TAB_VAR
  local expected_tab=$'col1\tcol2'
  assert_eq "tab decoded" "$expected_tab" "$TAB_VAR"
}

# ============================================================
# Test: Real workspace output passes whitelist
# ============================================================
test_real_workspace_output() {
  section "Real workspace output"

  local tmpfile
  tmpfile=$(mktemp --suffix=.toml)
  cat > "$tmpfile" << 'EOF'
[container]
service_name = "test-svc"
username = "testuser"
ubuntu_version = "24.04"

[plugins]
enable = ["proto"]

[ports]
forward = [3000]
EOF

  local output
  output=$(_uv_python "$PROJECT_ROOT/lib/toml_parser.py" workspace "$tmpfile")
  # Should succeed with the standard whitelist
  _parse_toml_output "$output" \
    WS_SERVICE_NAME WS_USERNAME WS_UBUNTU_VERSION \
    WS_PLUGINS WS_FORWARD_PORTS WS_APT_EXTRA \
    WS_VOLUME_NAMES WS_VOLUME_PATHS \
    WS_VSCODE_EXTENSIONS
  assert_eq "real workspace parsed" "test-svc" "$WS_SERVICE_NAME"

  rm -f "$tmpfile"
}

# ============================================================
# Test: Real plugin output passes whitelist
# ============================================================
test_real_plugin_output() {
  section "Real plugin output"

  local output
  output=$(_uv_python "$PROJECT_ROOT/lib/toml_parser.py" plugin "$PROJECT_ROOT/plugins/proto.toml")
  _parse_toml_output "$output" \
    PLUGIN_ID PLUGIN_NAME PLUGIN_DESCRIPTION PLUGIN_DEFAULT \
    PLUGIN_DOCKERFILE PLUGIN_REQUIRES_ROOT \
    PLUGIN_APT_PACKAGES \
    PLUGIN_VOLUME_NAMES PLUGIN_VOLUME_PATHS \
    PLUGIN_VERSION_PIN PLUGIN_VERSION_STRATEGY
  assert_eq "real plugin parsed" "proto" "$PLUGIN_NAME"
}

# ============================================================
# Run
# ============================================================

test_allowed_variables
test_unknown_variable_rejected
test_invalid_variable_name
test_empty_input
test_backtick_injection
test_whitelist_exact_match
test_unknown_type_prefix
test_array_parsing
test_escape_decoding
test_real_workspace_output
test_real_plugin_output

print_summary
