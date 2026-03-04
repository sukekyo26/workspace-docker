#!/bin/bash
# ============================================================
# lib/utils.sh - General-purpose utility functions
# ============================================================
# Provides: read_env_var, validate_symlink, detect_docker_gid,
#           _safe_eval_toml_output
# ============================================================

# ============================================================
# Safe eval with variable name whitelist
# ============================================================

# Evaluate TOML parser output safely with variable name whitelist
# Usage: _safe_eval_toml_output "$output" VAR1 VAR2 ...
# Only evaluates lines whose variable name is in the whitelist
_safe_eval_toml_output() {
    local output="$1"
    shift
    local -a allowed_keys=("$@")

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key="${line%%=*}"
        # Reject variable names with non-alphanumeric/underscore characters
        if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            echo "ERROR: Invalid variable name in TOML output: $key" >&2
            return 1
        fi
        local allowed=false
        for k in "${allowed_keys[@]}"; do
            if [[ "$key" == "$k" ]]; then
                allowed=true
                break
            fi
        done
        if [[ "$allowed" != true ]]; then
            echo "ERROR: Unexpected variable in TOML output: $key" >&2
            return 1
        fi
        eval "$line"
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
    value=$(awk -F= -v key="$var_name" '
        $1 == key {
            # Join all fields after the first with "=" to handle values containing "="
            val = ""
            for (i = 2; i <= NF; i++) {
                val = val (i > 2 ? "=" : "") $i
            }
            # Remove surrounding quotes if present
            gsub(/^["'\'']|["'\'']$/, "", val)
            print val
            exit
        }
    ' "$env_file")

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
        target=$(readlink "$symlink")
        if [[ ! "$target" =~ ^"$expected_dir" ]]; then
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
