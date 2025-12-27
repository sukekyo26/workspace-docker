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

# Validate package manager choice
# Usage: validate_package_manager "manager" "type"
# type can be "python" or "nodejs"
# Returns: 0 if valid, 1 if invalid
validate_package_manager() {
    local manager="$1"
    local type="$2"
    
    case "$type" in
        python)
            case "$manager" in
                none|uv|poetry|pyenv-uv|pyenv-poetry)
                    return 0
                    ;;
                *)
                    echo "ERROR: Invalid Python package manager: $manager" >&2
                    echo "Valid options: none, uv, poetry, pyenv-uv, pyenv-poetry" >&2
                    return 1
                    ;;
            esac
            ;;
        nodejs)
            case "$manager" in
                none|volta|nvm|fnm|mise)
                    return 0
                    ;;
                *)
                    echo "ERROR: Invalid Node.js package manager: $manager" >&2
                    echo "Valid options: none, volta, nvm, fnm, mise" >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "ERROR: Invalid package manager type: $type" >&2
            return 1
            ;;
    esac
}

# Validate setup mode
# Usage: validate_setup_mode "mode"
# Returns: 0 if valid, 1 if invalid
validate_setup_mode() {
    local mode="$1"
    
    if [[ "$mode" != "1" && "$mode" != "2" ]]; then
        echo "ERROR: Setup mode must be '1' (Normal) or '2' (Custom)" >&2
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
