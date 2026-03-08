#!/bin/bash
# ============================================================
# lib/utils.sh - General-purpose utility functions
# ============================================================
# Provides: read_env_var, validate_symlink, detect_docker_gid,
#           _parse_toml_output
# ============================================================
set -uo pipefail

# Load i18n
_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=i18n.sh
source "$_UTILS_LIB_DIR/i18n.sh"

# ============================================================
# TOML output parser (eval-free)
# ============================================================

# Parse TOML parser output safely using declare/printf (no eval).
#
# Input format (from toml_parser.py):
#   S:KEY=encoded_value     (scalar, printf %b encoded)
#   A:KEY=elem1\x1felem2    (array, elements separated by U+001F)
#
# Usage: _parse_toml_output "$output" VAR1 VAR2 ...
# Only processes lines whose variable name is in the whitelist.
_parse_toml_output() {
  local output="$1"
  shift
  local -a allowed_keys=("$@")

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Extract type prefix and key=value
    local type="${line:0:2}"
    local rest="${line:2}"
    local key="${rest%%=*}"
    local value="${rest#*=}"

    # Validate variable name (strict alphanumeric + underscore)
    if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
      echo "ERROR: $(msg err_invalid_var_name "$key")" >&2
      return 1
    fi

    # Whitelist check
    local allowed=false
    for k in "${allowed_keys[@]}"; do
      if [[ "$key" == "$k" ]]; then
        allowed=true
        break
      fi
    done
    if [[ "$allowed" != true ]]; then
      echo "ERROR: $(msg err_unexpected_var "$key")" >&2
      return 1
    fi

    if [[ "$type" == "A:" ]]; then
      # Array value
      if [[ -z "$value" ]]; then
        # Empty array — use nameref to assign without eval
        # shellcheck disable=SC2178,SC2034
        declare -n _arr_ref="$key"
        _arr_ref=()
        unset -n _arr_ref
      else
        # Split on unit separator (U+001F)
        local -a _raw_elems
        IFS=$'\x1f' read -ra _raw_elems <<< "$value"

        # Decode printf %b escapes in each element
        local -a _decoded_elems=()
        local _elem
        for _elem in "${_raw_elems[@]}"; do
          local _d
          printf -v _d '%b' "$_elem"
          _decoded_elems+=("$_d")
        done

        # Assign array via nameref (no eval)
        # shellcheck disable=SC2178,SC2034
        declare -n _arr_ref="$key"
        _arr_ref=("${_decoded_elems[@]}")
        unset -n _arr_ref
      fi
    elif [[ "$type" == "S:" ]]; then
      # Scalar value — decode and assign via printf -v (no eval)
      local _decoded_val
      printf -v _decoded_val '%b' "$value"
      printf -v "$key" '%s' "$_decoded_val"
    else
      echo "ERROR: $(msg err_unknown_type_prefix "${type}")" >&2
      return 1
    fi
  done <<< "$output"
}

# ============================================================
# Environment / Filesystem Utilities
# ============================================================

# Safely read environment variables from a .env file
# Usage: read_env_var "VAR_NAME" "file.env"
# Returns: value of VAR_NAME or empty string
read_env_var() {
  local var_name="$1"
  local env_file="$2"
  local value=""

  if [[ ! -f "$env_file" ]]; then
    return 1
  fi

  # Use awk to properly handle values containing '='
  if ! value=$(awk -F= -v key="$var_name" '
    $1 == key {
      # Join all fields after the first with "=" to handle values containing "="
      val = ""
      for (i = 2; i <= NF; i++) {
        val = val (i > 2 ? "=" : "") $i
      }
      # Remove surrounding quotes if present
      gsub(/^["'\'']|["'\'']$/, "", val)
      print val
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$env_file"); then
    return 1
  fi

  printf '%s' "$value"
}

# Validate symlink and its target
# Usage: validate_symlink "symlink_path" "expected_target_dir"
# Returns: 0 if valid, 1 if broken, 2 if not a symlink
validate_symlink() {
  local symlink="$1"
  local expected_dir="$2"

  # Check if symlink exists
  if [[ ! -L "$symlink" ]]; then
    return 2  # Not a symlink
  fi

  # Check if target exists
  if [[ ! -e "$symlink" ]]; then
    return 1  # Broken symlink
  fi

  # Optionally check if target is in expected directory
  if [[ -n "$expected_dir" ]]; then
    local target
    target=$(readlink -f "$symlink")
    # Ensure trailing slash to prevent prefix match (e.g. /home/user vs /home/user2)
    [[ "$expected_dir" != */ ]] && expected_dir="${expected_dir}/"
    if [[ "$target/" != "$expected_dir"* ]]; then
      return 1
    fi
  fi

  return 0
}

# Detect Docker GID with support for rootless mode
# Usage: detect_docker_gid
# Returns: Docker GID or exits with error
detect_docker_gid() {
  local docker_gid=""

  # Method 1: Check Docker socket directly
  if [[ -S /var/run/docker.sock ]]; then
    docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null)
    if [[ -n "$docker_gid" ]]; then
      echo "$docker_gid"
      return 0
    fi
  fi

  # Method 2: Check rootless Docker socket
  local rootless_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"
  if [[ -S "$rootless_socket" ]]; then
    docker_gid=$(stat -c '%g' "$rootless_socket" 2>/dev/null)
    if [[ -n "$docker_gid" ]]; then
      echo "$docker_gid"
      return 0
    fi
  fi

  # Method 3: Get from docker group
  docker_gid=$(getent group docker 2>/dev/null | cut -d: -f3)
  if [[ -n "$docker_gid" ]]; then
    echo "$docker_gid"
    return 0
  fi

  return 1
}
