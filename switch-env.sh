#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
generate_nvm_install() {
    if [ "$1" = "nvm" ]; then
        cat << 'EOF'
# nvm (Node.js version manager)
# Note: nvm install script automatically adds configuration to ~/.bashrc
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
ENV NVM_DIR="/home/${USERNAME}/.nvm"
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

echo -e "${CYAN}=== Switch Environment ===${NC}"

# Check if argument is provided
if [ $# -eq 1 ]; then
    container_service_name=$1
else
    # Prompt for container service name
    read -p "Enter container service name to switch to: " container_service_name
fi

# Check if empty
if [ -z "$container_service_name" ]; then
    echo -e "${RED}ERROR:${NC} Container service name cannot be empty"
    exit 1
fi

# Check if .envs/<service_name>.env file exists
if [ ! -f ".envs/$container_service_name.env" ]; then
    echo -e "${RED}ERROR:${NC} .envs/$container_service_name.env not found"
    echo "Available environments:"
    if [ -d ".envs" ]; then
        shopt -s nullglob
        env_files=(.envs/*.env)
        if [ ${#env_files[@]} -eq 0 ]; then
            echo -e "  ${YELLOW}No environments found${NC}"
        else
            for env_file in "${env_files[@]}"; do
                service_name=$(basename "$env_file" .env)
                echo -e "  ${CYAN}$service_name${NC}"
            done
        fi
        shopt -u nullglob
    else
        echo -e "  ${YELLOW}No environments found${NC}"
    fi
    exit 1
fi

# Get current environment
current_env=""
if [ -L ".env" ]; then
    current_link=$(readlink .env)
    if [[ "$current_link" == .envs/*.env ]]; then
        current_env=$(basename "$current_link" .env)
    fi
fi

# Check if already using this environment
if [ "$current_env" = "$container_service_name" ]; then
    echo -e "${YELLOW}INFO:${NC} Already using environment: $container_service_name"
    exit 0
fi

# Switch symlink
# Using relative path to ensure portability across different environments
ln -sf .envs/$container_service_name.env .env

# Read environment variables from the new .env file
CONTAINER_SERVICE_NAME=$(grep '^CONTAINER_SERVICE_NAME=' .env | cut -d'=' -f2-)
USERNAME_ENV=$(grep '^USERNAME=' .env | cut -d'=' -f2-)
SETUP_MODE=$(grep '^SETUP_MODE=' .env | cut -d'=' -f2-)
INSTALL_DOCKER=$(grep '^INSTALL_DOCKER=' .env | cut -d'=' -f2-)
INSTALL_AWS_CLI=$(grep '^INSTALL_AWS_CLI=' .env | cut -d'=' -f2-)
INSTALL_AWS_SAM_CLI=$(grep '^INSTALL_AWS_SAM_CLI=' .env | cut -d'=' -f2-)
INSTALL_GITHUB_CLI=$(grep '^INSTALL_GITHUB_CLI=' .env | cut -d'=' -f2-)
PYTHON_MANAGER=$(grep '^PYTHON_MANAGER=' .env | cut -d'=' -f2-)
NODEJS_MANAGER=$(grep '^NODEJS_MANAGER=' .env | cut -d'=' -f2-)

# Validate extracted variables
if [ -z "$CONTAINER_SERVICE_NAME" ]; then
    echo -e "${RED}ERROR:${NC} CONTAINER_SERVICE_NAME is missing from .envs/$container_service_name.env"
    exit 1
fi
if [ -z "$USERNAME_ENV" ]; then
    echo -e "${RED}ERROR:${NC} USERNAME is missing from .envs/$container_service_name.env"
    exit 1
fi
if [ -z "$SETUP_MODE" ]; then
    echo -e "${RED}ERROR:${NC} SETUP_MODE is missing from .envs/$container_service_name.env"
    exit 1
fi

# Regenerate docker-compose.yml
echo "Regenerating docker-compose.yml..."
if [ "$SETUP_MODE" = "1" ]; then
    # Normal mode: use basic template
    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$CONTAINER_SERVICE_NAME/g" \
        docker-compose.yml.template > docker-compose.yml
else
    # Custom mode: use custom template
    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$CONTAINER_SERVICE_NAME/g" \
        docker-compose.custom.template > docker-compose.yml
fi

# Regenerate Dockerfile
echo "Regenerating Dockerfile..."
if [ "$SETUP_MODE" = "1" ]; then
    # Normal mode: use basic template
    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$CONTAINER_SERVICE_NAME/g" \
        Dockerfile.template > Dockerfile
else
    # Custom mode: generate with selected tools
    # Default to false/none if variables are empty
    [ -z "$INSTALL_DOCKER" ] && INSTALL_DOCKER=false
    [ -z "$INSTALL_AWS_CLI" ] && INSTALL_AWS_CLI=false
    [ -z "$INSTALL_AWS_SAM_CLI" ] && INSTALL_AWS_SAM_CLI=false
    [ -z "$INSTALL_GITHUB_CLI" ] && INSTALL_GITHUB_CLI=false
    [ -z "$PYTHON_MANAGER" ] && PYTHON_MANAGER="none"
    [ -z "$NODEJS_MANAGER" ] && NODEJS_MANAGER="none"

    # Generate installation sections
    docker_install=$(generate_docker_install "$INSTALL_DOCKER")
    aws_cli_install=$(generate_aws_cli_install "$INSTALL_AWS_CLI")
    aws_sam_cli_install=$(generate_aws_sam_cli_install "$INSTALL_AWS_SAM_CLI")
    github_cli_install=$(generate_github_cli_install "$INSTALL_GITHUB_CLI")
    python3_install=$(generate_python3_install "$PYTHON_MANAGER")

    # Generate Python manager installation section
    case "$PYTHON_MANAGER" in
        "uv")
            python_install=$(generate_uv_install "uv")
            ;;
        "poetry")
            python_install=$(generate_poetry_install "poetry")
            ;;
        "pyenv-poetry")
            python_install=$(generate_pyenv_install "pyenv-poetry")
            python_install="$python_install"$'\n'"$(generate_poetry_install "pyenv-poetry")"
            ;;
        "mise")
            python_install=$(generate_mise_python_install "mise")
            ;;
        "none")
            python_install=""
            ;;
    esac

    # Generate Node.js manager installation section
    case "$NODEJS_MANAGER" in
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
        "none")
            nodejs_install=""
            ;;
    esac

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
    ' Dockerfile.custom.template > Dockerfile
fi

# Regenerate .devcontainer files
echo "Regenerating .devcontainer/devcontainer.json..."
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$CONTAINER_SERVICE_NAME/g" \
    -e "s/{{USERNAME}}/$USERNAME_ENV/g" \
    .devcontainer/devcontainer.json.template > .devcontainer/devcontainer.json

echo "Regenerating .devcontainer/docker-compose.yml..."
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$CONTAINER_SERVICE_NAME/g" \
    .devcontainer/docker-compose.yml.template > .devcontainer/docker-compose.yml

echo -e "${GREEN}=== Environment Switched ===${NC}"
if [ -n "$current_env" ]; then
    echo "From: $current_env"
fi
echo "To:   $container_service_name"
echo ""
echo "Environment variables loaded from: .envs/$container_service_name.env"
echo ""
echo "Regenerated files:"
echo "  - Dockerfile"
echo "  - docker-compose.yml"
echo "  - .devcontainer/devcontainer.json"
echo "  - .devcontainer/docker-compose.yml"
echo ""
echo "To apply changes, rebuild and restart the container:"
echo -e "  ${YELLOW}docker compose down${NC}"
echo -e "  ${YELLOW}docker compose build --no-cache${NC}"
echo -e "  ${YELLOW}docker compose up -d${NC}"
echo ""
echo -e "${RED}IMPORTANT:${NC} Rebuild is required because configuration may have changed"
