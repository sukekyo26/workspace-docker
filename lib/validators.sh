#!/bin/bash
# Input validation functions for setup scripts
# This library provides reusable validation functions
set -uo pipefail

# Load i18n
_VALIDATORS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=i18n.sh
source "$_VALIDATORS_LIB_DIR/i18n.sh"

# Validate container service name
# Usage: validate_service_name "name"
# Returns: 0 if valid, 1 if invalid
validate_service_name() {
  local name="$1"

  # Check if empty
  if [[ -z "$name" ]]; then
    echo "ERROR: $(msg err_service_name_empty)" >&2
    return 1
  fi

  # Check for valid characters (lowercase alphanumeric, dash, underscore, must start with letter)
  if [[ ! "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    echo "ERROR: $(msg err_service_name_invalid)" >&2
    return 1
  fi

  # Check length (Docker container names have limits)
  if [[ ${#name} -gt 64 ]]; then
    echo "ERROR: $(msg err_service_name_too_long)" >&2
    return 1
  fi

  return 0
}

# Validate username
# Usage: validate_username "username"
# Returns: 0 if valid, 1 if invalid
validate_username() {
  local username="$1"

  # Check if empty
  if [[ -z "$username" ]]; then
    echo "ERROR: $(msg err_username_empty)" >&2
    return 1
  fi

  # Block dangerous system usernames
  local blocked="root daemon bin sys sync games man lp mail news uucp proxy www-data backup list irc gnats nobody systemd-network systemd-resolve messagebus syslog _apt"
  local blocked_name
  for blocked_name in $blocked; do
    if [[ "$username" == "$blocked_name" ]]; then
      echo "ERROR: $(msg err_username_blocked "$username")" >&2
      return 1
    fi
  done

  # Check for valid Unix username format
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "ERROR: $(msg err_username_invalid)" >&2
    return 1
  fi

  # Check length (Unix usernames are typically limited)
  if [[ ${#username} -gt 32 ]]; then
    echo "ERROR: $(msg err_username_too_long)" >&2
    return 1
  fi

  return 0
}

# Validate boolean value
# Usage: validate_boolean "value"
# Returns: 0 if valid (true/false), 1 if invalid
validate_boolean() {
  local value="$1"

  if [[ "$value" != "true" && "$value" != "false" ]]; then
    echo "ERROR: $(msg err_boolean_invalid)" >&2
    return 1
  fi

  return 0
}

# Validate file exists
# Usage: validate_file_exists "filepath" "description"
# Returns: 0 if exists, 1 if not
validate_file_exists() {
  local filepath="$1"
  local description="$2"

  if [[ ! -f "$filepath" ]]; then
    echo "ERROR: $(msg err_file_not_found "$description" "$filepath")" >&2
    return 1
  fi

  return 0
}

# Validate directory exists
# Usage: validate_dir_exists "dirpath" "description"
# Returns: 0 if exists, 1 if not
validate_dir_exists() {
  local dirpath="$1"
  local description="$2"

  if [[ ! -d "$dirpath" ]]; then
    echo "ERROR: $(msg err_dir_not_found "$description" "$dirpath")" >&2
    return 1
  fi

  return 0
}

# Validate that apt packages don't duplicate base packages
# Usage: validate_no_duplicate_apt_packages "apt_base_packages_conf" "extra_pkg1" "extra_pkg2" ...
# Returns: 0 if no duplicates, 1 if duplicates found (prints warnings)
validate_no_duplicate_apt_packages() {
  local base_conf="$1"
  shift
  local extra_packages=("$@")

  if [[ ${#extra_packages[@]} -eq 0 || -z "${extra_packages[0]}" ]]; then
    return 0
  fi

  if [[ ! -f "$base_conf" ]]; then
    return 0
  fi

  # Build set of base packages
  local found_duplicates=false
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
    pkg="${pkg#"${pkg%%[![:space:]]*}"}"
    pkg="${pkg%"${pkg##*[![:space:]]}"}"
    [[ -z "$pkg" ]] && continue

    for extra in "${extra_packages[@]}"; do
      if [[ "$extra" == "$pkg" ]]; then
        echo "WARNING: $(msg warn_apt_duplicate "$extra")" >&2
        found_duplicates=true
      fi
    done
  done < "$base_conf"

  if [[ "$found_duplicates" == true ]]; then
    echo "WARNING: $(msg warn_apt_remove_duplicates)" >&2
    return 1
  fi

  return 0
}
