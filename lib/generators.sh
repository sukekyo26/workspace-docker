#!/bin/bash
# Common generator functions for Dockerfile sections
# This library is shared between setup-docker.sh and switch-env.sh

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load version configuration
# shellcheck source=versions.conf
source "$LIB_DIR/versions.conf"

# Function to generate Docker CLI installation section
generate_docker_install() {
    if [ "$1" = true ]; then
        cat << 'EOF'
# Install Docker CLI (client only, to use host Docker daemon via socket mount)
USER root
RUN apt-get update && \
    apt-get install -y ca-certificates gnupg lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -f docker && \
    usermod -aG docker ${USERNAME}

USER ${USERNAME}
EOF
    else
        echo ""
    fi
}

# Function to generate python3 system package installation (for poetry)
generate_python3_install() {
    if [ "$1" = "poetry" ] || [ "$1" = "pyenv-poetry" ]; then
        cat << 'EOF'

# Install python3 for poetry
RUN apt update -y && \
    apt install -y python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*
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
    out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    mkdir -p -m 755 /etc/apt/sources.list.d && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*
USER ${USERNAME}
EOF
    else
        echo ""
    fi
}

# Function to generate uv installation section
generate_uv_install() {
    if [ "$1" = "uv" ]; then
        cat << 'EOF'
# uv (Python package manager and version manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
EOF
    else
        echo ""
    fi
}

# Function to generate poetry installation section
generate_poetry_install() {
    if [ "$1" = "poetry" ] || [ "$1" = "pyenv-poetry" ]; then
        cat << 'EOF'
# Poetry (Python dependency management)
RUN curl -sSL https://install.python-poetry.org | python3 - && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate pyenv installation section
generate_pyenv_install() {
    if [ "$1" = "pyenv-poetry" ]; then
        cat << 'EOF'
# pyenv (Python version management)
RUN git clone https://github.com/pyenv/pyenv.git ~/.pyenv && \
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
ENV PYENV_ROOT="/home/${USERNAME}/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate mise installation section for Python
generate_mise_python_install() {
    if [ "$1" = "mise" ]; then
        cat << 'EOF'
# mise (multi-language version manager) for Python
RUN curl https://mise.run | sh && \
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate Volta installation section
generate_volta_install() {
    if [ "$1" = "volta" ]; then
        cat << 'EOF'
# Volta (Node.js version manager)
RUN curl https://get.volta.sh | bash
ENV VOLTA_HOME="/home/${USERNAME}/.volta"
ENV PATH="$VOLTA_HOME/bin:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate nvm installation section
# Uses NVM_VERSION from versions.conf
generate_nvm_install() {
    if [ "$1" = "nvm" ]; then
        cat << EOF
# nvm (Node.js version manager)
# Note: nvm install script automatically adds configuration to ~/.bashrc
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash
ENV NVM_DIR="/home/\${USERNAME}/.nvm"
EOF
    else
        echo ""
    fi
}

# Function to generate fnm installation section
generate_fnm_install() {
    if [ "$1" = "fnm" ]; then
        cat << 'EOF'
# fnm (Fast Node Manager)
# Note: fnm install script automatically adds configuration to ~/.bashrc
RUN curl -fsSL https://fnm.vercel.app/install | bash
ENV PATH="/home/${USERNAME}/.local/share/fnm:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate mise installation section for Node.js
generate_mise_nodejs_install() {
    if [ "$1" = "mise" ]; then
        # Only install mise if not already installed by Python manager
        cat << 'EOF'
# mise (multi-language version manager) for Node.js
# Note: If already installed for Python, this will be skipped
RUN if [ ! -f ~/.local/bin/mise ]; then \
        curl https://mise.run | sh && \
        echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc; \
    fi
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"
EOF
    else
        echo ""
    fi
}

# Function to generate Python manager installation based on selection
generate_python_manager_install() {
    local python_manager="$1"
    local python_install=""

    case "$python_manager" in
        "uv")
            python_install=$(generate_uv_install "uv")
            ;;
        "poetry")
            python_install=$(generate_poetry_install "poetry")
            ;;
        "pyenv-poetry")
            local pyenv_inst
            local poetry_inst
            pyenv_inst=$(generate_pyenv_install "pyenv-poetry")
            poetry_inst=$(generate_poetry_install "pyenv-poetry")
            python_install="${pyenv_inst}

${poetry_inst}"
            ;;
        "mise")
            python_install=$(generate_mise_python_install "mise")
            ;;
        "none"|"")
            python_install=""
            ;;
    esac

    echo "$python_install"
}

# Function to generate Node.js manager installation based on selection
generate_nodejs_manager_install() {
    local nodejs_manager="$1"
    local nodejs_install=""

    case "$nodejs_manager" in
        "volta")
            nodejs_install=$(generate_volta_install "volta")
            ;;
        "nvm")
            nodejs_install=$(generate_nvm_install "nvm")
            ;;
        "fnm")
            nodejs_install=$(generate_fnm_install "fnm")
            ;;
        "mise")
            nodejs_install=$(generate_mise_nodejs_install "mise")
            ;;
        "none"|"")
            nodejs_install=""
            ;;
    esac

    echo "$nodejs_install"
}

# Function to generate Dockerfile from custom template
generate_dockerfile_from_template() {
    local template_file="$1"
    local output_file="$2"
    local install_docker="$3"
    local install_aws_cli="$4"
    local install_aws_sam_cli="$5"
    local install_github_cli="$6"
    local python_manager="$7"
    local nodejs_manager="$8"

    local docker_install
    local aws_cli_install
    local aws_sam_cli_install
    local github_cli_install
    local python3_install
    local python_install
    local nodejs_install

    docker_install=$(generate_docker_install "$install_docker")
    aws_cli_install=$(generate_aws_cli_install "$install_aws_cli")
    aws_sam_cli_install=$(generate_aws_sam_cli_install "$install_aws_sam_cli")
    github_cli_install=$(generate_github_cli_install "$install_github_cli")
    python3_install=$(generate_python3_install "$python_manager")
    python_install=$(generate_python_manager_install "$python_manager")
    nodejs_install=$(generate_nodejs_manager_install "$nodejs_manager")

    # Use awk for better multiline handling
    awk -v docker_inst="$docker_install" \
        -v aws_inst="$aws_cli_install" \
        -v aws_sam_inst="$aws_sam_cli_install" \
        -v github_inst="$github_cli_install" \
        -v python3_inst="$python3_install" \
        -v python_inst="$python_install" \
        -v nodejs_inst="$nodejs_install" '
        /{{DOCKER_INSTALL}}/ { print docker_inst; next }
        /{{AWS_CLI_INSTALL}}/ { print aws_inst; next }
        /{{AWS_SAM_CLI_INSTALL}}/ { print aws_sam_inst; next }
        /{{GITHUB_CLI_INSTALL}}/ { print github_inst; next }
        /{{PYTHON3_INSTALL}}/ { print python3_inst; next }
        /{{PYTHON_MANAGER_INSTALL}}/ { print python_inst; next }
        /{{NODEJS_MANAGER_INSTALL}}/ { print nodejs_inst; next }
        { print }
    ' "$template_file" > "$output_file"
}
