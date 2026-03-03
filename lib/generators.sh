#!/bin/bash
# Common generator functions for Dockerfile sections
# This library is shared between setup-docker.sh and rebuild-container.sh

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load plugin system
# shellcheck source=plugin.sh
source "$LIB_DIR/plugin.sh"

# ============================================================
# Utility Functions
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

# ============================================================
# Docker Compose Volume Functions
# ============================================================

# Generate docker-compose.yml from template with plugin-based volumes
# Usage: generate_compose_from_template "template" "output" "service_name" "workspace_toml"
generate_compose_from_template() {
    local template_file="$1"
    local output_file="$2"
    local service_name="$3"
    local workspace_toml="$4"

    load_workspace_config "$workspace_toml"
    generate_plugin_volumes "${WS_PLUGINS[@]}"

    awk -v service_name="$service_name" \
        -v vol_mounts="$_OPTIONAL_VOLUME_MOUNTS" \
        -v vol_defs="$_OPTIONAL_VOLUME_DEFINITIONS" '
        /{{CONTAINER_SERVICE_NAME}}/ { gsub(/{{CONTAINER_SERVICE_NAME}}/, service_name); print; next }
        /{{OPTIONAL_VOLUME_MOUNTS}}/ { if (vol_mounts != "") print vol_mounts; next }
        /{{OPTIONAL_VOLUME_DEFINITIONS}}/ { if (vol_defs != "") print vol_defs; next }
        { print }
    ' "$template_file" > "$output_file"
}

# Generate devcontainer.json from template
# Usage: generate_devcontainer_json_from_template "template" "output" "service_name" "username" "forward_port"
generate_devcontainer_json_from_template() {
    local template_file="$1"
    local output_file="$2"
    local service_name="$3"
    local username="$4"
    local forward_port="$5"

    awk -v service_name="$service_name" \
        -v username="$username" \
        -v forward_port="$forward_port" '
        {
            gsub(/{{CONTAINER_SERVICE_NAME}}/, service_name)
            gsub(/{{USERNAME}}/, username)
            gsub(/{{FORWARD_PORT}}/, forward_port)
            print
        }
    ' "$template_file" > "$output_file"
}

# Generate .devcontainer/docker-compose.yml from template
# Usage: generate_devcontainer_compose_from_template "template" "output" "service_name"
generate_devcontainer_compose_from_template() {
    local template_file="$1"
    local output_file="$2"
    local service_name="$3"

    awk -v service_name="$service_name" '
        /{{CONTAINER_SERVICE_NAME}}/ { gsub(/{{CONTAINER_SERVICE_NAME}}/, service_name); print; next }
        { print }
    ' "$template_file" > "$output_file"
}

# ============================================================
# Certificate Functions
# ============================================================

# Get the root directory of the workspace-docker project
# Usage: get_project_root
# Returns: absolute path to workspace-docker root
get_project_root() {
    # LIB_DIR is set at the top of this file
    (cd "$LIB_DIR/.." && pwd)
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

# ============================================================
# Dockerfile Generator Functions
# ============================================================

# Function to generate custom certificate installation section
# This function generates Dockerfile commands to install custom CA certificates
# Automatically detects certificates in certs/ directory
generate_certificate_install() {
    local certs
    certs=$(list_valid_certificates)

    if [[ -z "$certs" ]]; then
        echo ""
        return
    fi

    # Build the COPY and installation commands
    local copy_commands=""
    local cp_commands=""
    local cert_count=0

    while IFS= read -r cert_name; do
        if [[ -n "$cert_name" ]]; then
            copy_commands="${copy_commands}COPY certs/${cert_name} /tmp/certs/${cert_name}
"
            if [[ $cert_count -gt 0 ]]; then
                cp_commands="${cp_commands} && \\
"
            fi
            cp_commands="${cp_commands}    cp /tmp/certs/${cert_name} /usr/local/share/ca-certificates/${cert_name}"
            ((cert_count++))
        fi
    done <<< "$certs"

    cat << EOF
# Install custom CA certificates for corporate proxy/VPN environments
USER root
${copy_commands}RUN mkdir -p /usr/local/share/ca-certificates && \\
${cp_commands} && \\
    update-ca-certificates && \\
    rm -rf /tmp/certs && \\
    echo 'export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' >> /home/\${USERNAME}/.bashrc && \\
    echo 'export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' >> /home/\${USERNAME}/.bashrc && \\
    echo 'export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' >> /home/\${USERNAME}/.bashrc && \\
    echo 'export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt' >> /home/\${USERNAME}/.bashrc
USER \${USERNAME}

# Set certificate environment variables for various tools
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
EOF
}

# Function to generate Dockerfile from template using plugin system
# Usage: generate_dockerfile_from_template "template" "output" "workspace_toml"
generate_dockerfile_from_template() {
    local template_file="$1"
    local output_file="$2"
    local workspace_toml="$3"

    load_workspace_config "$workspace_toml"

    local plugin_installs
    plugin_installs=$(generate_plugin_installs "${WS_PLUGINS[@]}")

    local certificate_install
    certificate_install=$(generate_certificate_install)

    # Build apt base packages from config file
    local apt_base=""
    local apt_conf
    apt_conf="$(cd "$(dirname "$template_file")" && pwd)/config/apt-base-packages.conf"
    if [[ -f "$apt_conf" ]]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Trim whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && apt_base="${apt_base}    ${line} \\
"
        done < "$apt_conf"
    fi

    # Build apt extra packages lines
    local apt_extra=""
    if [[ ${#WS_APT_EXTRA[@]} -gt 0 && -n "${WS_APT_EXTRA[0]}" ]]; then
        for pkg in "${WS_APT_EXTRA[@]}"; do
            apt_extra="${apt_extra}    ${pkg} \\
"
        done
    fi

    # Use awk for multiline placeholder replacement
    # Note: awk -v interprets backslash escapes, so we use ENVIRON[] instead
    # to preserve backslash-newline continuations in Dockerfile RUN commands
    PLUGIN_INST="$plugin_installs" \
    CERT_INST="$certificate_install" \
    APT_BASE="$apt_base" \
    APT_EXTRA="$apt_extra" \
    awk '
        /{{PLUGIN_INSTALLS}}/ { print ENVIRON["PLUGIN_INST"]; next }
        /{{CUSTOM_CERTIFICATES}}/ { print ENVIRON["CERT_INST"]; next }
        /{{APT_BASE_PACKAGES}}/ { if (ENVIRON["APT_BASE"] != "") printf "%s", ENVIRON["APT_BASE"]; next }
        /{{APT_EXTRA_PACKAGES}}/ { if (ENVIRON["APT_EXTRA"] != "") printf "%s", ENVIRON["APT_EXTRA"]; next }
        { print }
    ' "$template_file" > "$output_file"
}
