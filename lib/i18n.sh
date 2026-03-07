#!/bin/bash
# ============================================================
# lib/i18n.sh - Internationalization framework
# ============================================================
# Message catalog using bash associative arrays.
# Set WORKSPACE_LANG=ja for Japanese (default: en).
#
# Usage:
#   source lib/i18n.sh
#   info "$(msg setup_generating_dockerfile)"
#   error "$(msg err_file_not_found "Config" "/path/to/file")"
# ============================================================
set -uo pipefail

declare -gA _MSG=()

# Load locale files from locale/ directory
_load_locale() {
  local lang="${WORKSPACE_LANG:-en}"
  local locale_dir
  locale_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/locale"

  # Always load English first (fallback)
  # shellcheck source=/dev/null
  source "$locale_dir/en.sh"

  # Overlay requested locale if different from English
  if [[ "$lang" != "en" && -f "$locale_dir/${lang}.sh" ]]; then
    # shellcheck source=/dev/null
    source "$locale_dir/${lang}.sh"
  fi
}

# Get translated message with optional printf formatting (no trailing newline)
# Usage: msg "key" [args...]
# Usage in other functions: error "$(msg key args...)"
msg() {
  local key="$1"
  shift
  # shellcheck disable=SC2059
  printf "${_MSG[$key]:-$key}" "$@"
}

# Print translated message with trailing newline
# Usage: msgln "key" [args...]
msgln() {
  local key="$1"
  shift
  # shellcheck disable=SC2059
  printf "${_MSG[$key]:-$key}\n" "$@"
}

_load_locale
