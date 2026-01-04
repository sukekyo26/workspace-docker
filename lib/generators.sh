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

    # Method 4: Fallback to common default
    # Docker typically uses GID 999 or 998
    if getent group 999 >/dev/null 2>&1; then
        echo "999"
        return 0
    fi

    return 1
}

# ============================================================
# Dockerfile Generator Functions
# ============================================================

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

    docker_install=$(generate_docker_install "$install_docker")
    aws_cli_install=$(generate_aws_cli_install "$install_aws_cli")
    aws_sam_cli_install=$(generate_aws_sam_cli_install "$install_aws_sam_cli")
    github_cli_install=$(generate_github_cli_install "$install_github_cli")
    zig_install=$(generate_zig_install "$install_zig")

    # Use awk for better multiline handling
    awk -v docker_inst="$docker_install" \
        -v aws_inst="$aws_cli_install" \
        -v aws_sam_inst="$aws_sam_cli_install" \
        -v github_inst="$github_cli_install" \
        -v zig_inst="$zig_install" '
        /{{DOCKER_INSTALL}}/ { print docker_inst; next }
        /{{AWS_CLI_INSTALL}}/ { print aws_inst; next }
        /{{AWS_SAM_CLI_INSTALL}}/ { print aws_sam_inst; next }
        /{{GITHUB_CLI_INSTALL}}/ { print github_inst; next }
        /{{ZIG_INSTALL}}/ { print zig_inst; next }
        { print }
    ' "$template_file" > "$output_file"
}
