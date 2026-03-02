#!/bin/bash
# Input validation functions for setup scripts
# This library provides reusable validation functions

# Validate container service name
# Usage: validate_service_name "name"
# Returns: 0 if valid, 1 if invalid
validate_service_name() {
    local name="$1"

    # Check if empty
    if [[ -z "$name" ]]; then
        echo "ERROR: Container service name cannot be empty" >&2
        return 1
    fi

    # Check for valid characters (alphanumeric, dash, underscore)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Container service name must contain only alphanumeric characters, dashes, and underscores" >&2
        return 1
    fi

    # Check length (Docker container names have limits)
    if [[ ${#name} -gt 64 ]]; then
        echo "ERROR: Container service name must be 64 characters or less" >&2
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
        echo "ERROR: Username cannot be empty" >&2
        return 1
    fi

    # Check for valid Unix username format
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "ERROR: Username must start with lowercase letter or underscore, followed by lowercase letters, digits, underscores, or hyphens" >&2
        return 1
    fi

    # Check length (Unix usernames are typically limited)
    if [[ ${#username} -gt 32 ]]; then
        echo "ERROR: Username must be 32 characters or less" >&2
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
        echo "ERROR: Value must be 'true' or 'false'" >&2
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
        echo "ERROR: $description not found: $filepath" >&2
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
        echo "ERROR: $description not found: $dirpath" >&2
        return 1
    fi

    return 0
}

# Validate that apt extra_packages don't duplicate base packages
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
                echo "WARNING: [apt] extra_packages contains '${extra}', which is already in apt-base-packages.conf" >&2
                found_duplicates=true
            fi
        done
    done < "$base_conf"

    if [[ "$found_duplicates" == true ]]; then
        echo "WARNING: Remove duplicates from [apt] extra_packages in workspace.toml to avoid redundant installs" >&2
        return 1
    fi

    return 0
}
