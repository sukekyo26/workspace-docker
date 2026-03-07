#!/bin/bash
# ============================================================
# tests/unit/lib/test_i18n.sh
# Tests for lib/i18n.sh
# ============================================================

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
# shellcheck source=../../test_helper.sh
source "$TESTS_DIR/test_helper.sh"

echo ""
echo "[ test_i18n.sh ]"

# ============================================================
# Test: default locale (en)
# ============================================================
test_default_locale() {
  section "Default locale (en)"

  # Ensure clean state
  unset WORKSPACE_LANG 2>/dev/null || true
  declare -gA _MSG=()
  source "$PROJECT_ROOT/lib/i18n.sh"

  # msg() returns catalog value
  local result
  result=$(msg err_service_name_empty)
  assert_eq "msg returns English text" "Container service name cannot be empty" "$result"

  # msg() with printf arguments
  result=$(msg err_file_not_found "Config" "/path/to/file")
  assert_eq "msg with args" "Config not found: /path/to/file" "$result"

  # msg() returns key when missing
  result=$(msg nonexistent_key)
  assert_eq "msg returns key for missing entry" "nonexistent_key" "$result"
}

# ============================================================
# Test: Japanese locale
# ============================================================
test_japanese_locale() {
  section "Japanese locale (ja)"

  export WORKSPACE_LANG=ja
  declare -gA _MSG=()
  source "$PROJECT_ROOT/lib/i18n.sh"

  local result
  result=$(msg err_service_name_empty)
  assert_eq "msg returns Japanese text" "コンテナサービス名が空です" "$result"

  result=$(msg err_file_not_found "設定" "/path/to/file")
  assert_eq "msg with args (ja)" "設定 が見つかりません: /path/to/file" "$result"

  unset WORKSPACE_LANG
}

# ============================================================
# Test: locale fallback
# ============================================================
test_locale_fallback() {
  section "Locale fallback"

  export WORKSPACE_LANG=fr
  declare -gA _MSG=()
  source "$PROJECT_ROOT/lib/i18n.sh"

  # Non-existent locale should fall back to English
  local result
  result=$(msg err_service_name_empty)
  assert_eq "fallback to English for unknown locale" "Container service name cannot be empty" "$result"

  unset WORKSPACE_LANG
}

# ============================================================
# Test: all English keys have Japanese translations
# ============================================================
test_translation_completeness() {
  section "Translation completeness"

  # Load English
  unset WORKSPACE_LANG 2>/dev/null || true
  declare -gA _MSG=()
  source "$PROJECT_ROOT/locale/en.sh"
  local en_keys=()
  local key
  for key in "${!_MSG[@]}"; do
    en_keys+=("$key")
  done

  # Load Japanese
  declare -gA _MSG=()
  source "$PROJECT_ROOT/locale/en.sh"
  source "$PROJECT_ROOT/locale/ja.sh"

  # Check all English keys exist in Japanese
  local missing=0
  for key in "${en_keys[@]}"; do
    if [[ -z "${_MSG[$key]:-}" ]]; then
      echo "  Missing Japanese translation: $key" >&2
      missing=$((missing + 1))
    fi
  done
  assert_eq "all English keys have Japanese translations" "0" "$missing"
}

# ============================================================
# Run tests
# ============================================================
test_default_locale
test_japanese_locale
test_locale_fallback
test_translation_completeness

print_summary
