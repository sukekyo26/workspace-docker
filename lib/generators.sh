#!/bin/bash
# Common generator functions for Dockerfile sections
# This library is shared between setup-docker.sh and switch-env.sh

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load version configuration
# shellcheck source=versions.conf
source "$LIB_DIR/versions.conf"

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
# Certificate Functions
# ============================================================

# Get the root directory of the workspace-docker project
# Usage: get_project_root
# Returns: absolute path to workspace-docker root
get_project_root() {
    # LIB_DIR is set at the top of this file
    echo "$(cd "$LIB_DIR/.." && pwd)"
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

# Function to generate Docker CLI installation section
generate_docker_install() {
    if [ "$1" = true ]; then
        cat << 'EOF'
# Install Docker CLI (client only, to use host Docker daemon via socket mount)
USER root
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    groupadd -f docker && \
    usermod -aG docker ${USERNAME}

USER ${USERNAME}
EOF
    else
        echo ""
    fi
}

# Function to generate AWS CLI installation section
generate_aws_cli_install() {
    if [ "$1" = true ]; then
        cat << 'EOF'
# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    sudo ./aws/install && \
    rm -rf aws awscliv2.zip
EOF
    else
        echo ""
    fi
}

# Function to generate AWS SAM CLI installation section
generate_aws_sam_cli_install() {
    if [ "$1" = true ]; then
        cat << 'EOF'
# Install AWS SAM CLI
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
        amd64) DOWNLOAD_ARCH="x86_64" ;; \
        arm64) DOWNLOAD_ARCH="aarch64" ;; \
        *) DOWNLOAD_ARCH="x86_64" ;; \
    esac && \
    echo "Detected architecture: $ARCH -> $DOWNLOAD_ARCH" && \
    curl -L "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-${DOWNLOAD_ARCH}.zip" -o "aws-sam-cli.zip" && \
    unzip aws-sam-cli.zip -d sam-installation && \
    sudo ./sam-installation/install && \
    rm -rf sam-installation aws-sam-cli.zip
EOF
    else
        echo ""
    fi
}

# Function to generate GitHub CLI installation section
generate_github_cli_install() {
    if [ "$1" = true ]; then
        cat << 'EOF'
# Install GitHub CLI
USER root
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER ${USERNAME}
EOF
    else
        echo ""
    fi
}

# Function to generate Zig installation section
generate_zig_install() {
    if [ "$1" = true ]; then
        cat << EOF
# Install Zig (required for cargo-lambda cross-compilation)
USER root
RUN ARCH="\$(dpkg --print-architecture)" && \\
    case "\$ARCH" in \\
        amd64) DOWNLOAD_ARCH="x86_64" ;; \\
        arm64) DOWNLOAD_ARCH="aarch64" ;; \\
        *) DOWNLOAD_ARCH="x86_64" ;; \\
    esac && \\
    echo "Detected architecture: \$ARCH -> \$DOWNLOAD_ARCH" && \\
    curl -fsSL "https://ziglang.org/builds/zig-\${DOWNLOAD_ARCH}-linux-${ZIG_VERSION}.tar.xz" -o /tmp/zig.tar.xz && \\
    mkdir -p /usr/local/zig && \\
    tar -xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1 && \\
    ln -s /usr/local/zig/zig /usr/local/bin/zig && \\
    rm /tmp/zig.tar.xz
USER \${USERNAME}
EOF
    else
        echo ""
    fi
}

# Function to generate Dockerfile from custom template
generate_dockerfile_from_template() {
    local template_file="$1"
    local output_file="$2"
    local install_docker="$3"
    local install_aws_cli="$4"
    local install_aws_sam_cli="$5"
    local install_github_cli="$6"
    local install_zig="$7"

    local docker_install
    local aws_cli_install
    local aws_sam_cli_install
    local github_cli_install
    local zig_install
    local certificate_install

    docker_install=$(generate_docker_install "$install_docker")
    aws_cli_install=$(generate_aws_cli_install "$install_aws_cli")
    aws_sam_cli_install=$(generate_aws_sam_cli_install "$install_aws_sam_cli")
    github_cli_install=$(generate_github_cli_install "$install_github_cli")
    zig_install=$(generate_zig_install "$install_zig")
    certificate_install=$(generate_certificate_install)

    # Use awk for better multiline handling
    awk -v docker_inst="$docker_install" \
        -v aws_inst="$aws_cli_install" \
        -v aws_sam_inst="$aws_sam_cli_install" \
        -v github_inst="$github_cli_install" \
        -v zig_inst="$zig_install" \
        -v cert_inst="$certificate_install" '
        /{{DOCKER_INSTALL}}/ { print docker_inst; next }
        /{{AWS_CLI_INSTALL}}/ { print aws_inst; next }
        /{{AWS_SAM_CLI_INSTALL}}/ { print aws_sam_inst; next }
        /{{GITHUB_CLI_INSTALL}}/ { print github_inst; next }
        /{{ZIG_INSTALL}}/ { print zig_inst; next }
        /{{CUSTOM_CERTIFICATES}}/ { print cert_inst; next }
        { print }
    ' "$template_file" > "$output_file"
}
