#!/bin/bash
# ============================================================
# lib/certificates.sh - Certificate validation and management
# ============================================================
# Provides: get_project_root, validate_certificate,
#           list_valid_certificates, has_valid_certificates
# ============================================================

# Get the directory where this script is located
_CERTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the root directory of the workspace-docker project
# Usage: get_project_root
# Returns: absolute path to workspace-docker root
get_project_root() {
    (cd "$_CERTS_LIB_DIR/.." && pwd)
}

# Validate a certificate file format
# Usage: validate_certificate "path/to/cert.crt"
# Returns: 0 if valid PEM certificate, 1 if invalid
validate_certificate() {
    local cert_file="$1"

    # Check file exists
    if [[ ! -f "$cert_file" ]]; then
        return 1
    fi

    # Check file extension
    if [[ ! "$cert_file" =~ \.crt$ ]]; then
        return 1
    fi

    # Check PEM format (starts with -----BEGIN CERTIFICATE-----)
    if ! head -1 "$cert_file" | grep -q "^-----BEGIN CERTIFICATE-----"; then
        return 1
    fi

    # Check PEM format (contains -----END CERTIFICATE-----)
    if ! grep -q "^-----END CERTIFICATE-----" "$cert_file"; then
        return 1
    fi

    return 0
}

# List valid certificate files in certs directory
# Usage: list_valid_certificates
# Returns: newline-separated list of valid certificate filenames (not paths)
list_valid_certificates() {
    local project_root
    project_root=$(get_project_root)
    local certs_dir="$project_root/certs"

    if [[ ! -d "$certs_dir" ]]; then
        return 0
    fi

    # Find all .crt files and validate them
    shopt -s nullglob
    local crt_files=("$certs_dir"/*.crt)
    shopt -u nullglob

    for crt_file in "${crt_files[@]}"; do
        if validate_certificate "$crt_file"; then
            basename "$crt_file"
        fi
    done
}

# Check if valid certificates exist in certs directory
# Usage: has_valid_certificates
# Returns: 0 if at least one valid certificate exists, 1 otherwise
has_valid_certificates() {
    local certs
    certs=$(list_valid_certificates)
    [[ -n "$certs" ]]
}
