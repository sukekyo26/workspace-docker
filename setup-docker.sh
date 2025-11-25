#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Generate Dockerfile for Ubuntu on Docker ===${NC}"

# Check if ~/.gitconfig exists
if [ ! -f ~/.gitconfig ]; then
    echo -e "${RED}ERROR:${NC} ~/.gitconfig not found"
    echo -e "${YELLOW}Please configure Git first:${NC}"
    echo ""
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email \"your.email@example.com\""
    echo ""
    exit 1
fi

# Set container service name
while true; do
    read -p "Enter container service name: " container_service_name

    # Check if empty
    if [ -z "$container_service_name" ]; then
        echo -e "${RED}ERROR:${NC} Container service name cannot be empty"
        continue
    fi

    # Validate container service name (alphanumeric, hyphen, underscore only)
    if ! [[ "$container_service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}ERROR:${NC} Container service name must contain only alphanumeric characters, '-', and '_'"
        continue
    fi

    # Check length (max 63 characters for DNS compatibility)
    if [ ${#container_service_name} -gt 63 ]; then
        echo -e "${RED}ERROR:${NC} Container service name must be 63 characters or less (current: ${#container_service_name})"
        continue
    fi

    break
done

# Set username
while true; do
    read -p "Enter Ubuntu on Docker username: " username

    # Check if empty
    if [ -z "$username" ]; then
        echo -e "${RED}ERROR:${NC} Username cannot be empty"
        continue
    fi

    # Validate username (must start with lowercase letter or underscore)
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}ERROR:${NC} Username must start with a lowercase letter or '_', and contain only lowercase letters, numbers, '-', and '_'"
        continue
    fi

    # Check length (max 32 characters for Linux compatibility)
    if [ ${#username} -gt 32 ]; then
        echo -e "${RED}ERROR:${NC} Username must be 32 characters or less (current: ${#username})"
        continue
    fi

    break
done

# Ask for setup mode
echo ""
echo "Select setup mode:"
echo "  1) Normal (Quick start - recommended tools pre-installed)"
echo "  2) Custom (Select software to install)"
echo ""
while true; do
    read -p "Enter setup mode [1/2]: " setup_mode

    case $setup_mode in
        1|2)
            break
            ;;
        *)
            echo -e "${RED}ERROR:${NC} Please enter 1 or 2"
            continue
            ;;
    esac
done

# Initialize software installation flags
install_docker=true
install_aws_cli=true
python_manager="uv"    # Default: uv
nodejs_manager="volta" # Default: volta

# Custom mode: ask for each software
if [ "$setup_mode" = "2" ]; then
    echo ""
    echo -e "${CYAN}=== Software Installation Selection ===${NC}"

    # Docker CLI
    while true; do
        read -p "Install Docker CLI? [Y/n]: " choice
        choice=${choice:-Y}  # Default to Y if empty
        case $choice in
            y|Y) install_docker=true; break ;;
            n|N) install_docker=false; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter Y or n" ;;
        esac
    done

    # AWS CLI v2
    while true; do
        read -p "Install AWS CLI v2? [Y/n]: " choice
        choice=${choice:-Y}  # Default to Y if empty
        case $choice in
            y|Y) install_aws_cli=true; break ;;
            n|N) install_aws_cli=false; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter Y or n" ;;
        esac
    done

    # Python package manager selection
    echo ""
    echo "Select Python package manager:"
    echo "  1) uv (recommended: fast, all-in-one)"
    echo "  2) poetry (project management focused)"
    echo "  3) pyenv + poetry (version + project management)"
    echo "  4) mise (multi-language version manager)"
    echo "  5) none (skip Python tools)"
    while true; do
        read -p "Enter choice [1-5] (default: 1): " choice
        choice=${choice:-1}
        case $choice in
            1) python_manager="uv"; break ;;
            2) python_manager="poetry"; break ;;
            3) python_manager="pyenv-poetry"; break ;;
            4) python_manager="mise"; break ;;
            5) python_manager="none"; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter 1-5" ;;
        esac
    done

    # Node.js package manager selection
    echo ""
    echo "Select Node.js version manager:"
    echo "  1) Volta (recommended: auto-switching)"
    echo "  2) nvm (traditional, widely used)"
    echo "  3) fnm (fast, Rust-based)"
    echo "  4) mise (multi-language version manager)"
    echo "  5) none (skip Node.js tools)"
    while true; do
        read -p "Enter choice [1-5] (default: 1): " choice
        choice=${choice:-1}
        case $choice in
            1) nodejs_manager="volta"; break ;;
            2) nodejs_manager="nvm"; break ;;
            3) nodejs_manager="fnm"; break ;;
            4) nodejs_manager="mise"; break ;;
            5) nodejs_manager="none"; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter 1-5" ;;
        esac
    done
fi

# Automatically get UID and GID from current user
uid=$(id -u)
gid=$(id -g)

# Automatically get Docker socket GID (host's Docker group GID)
if [ -S /var/run/docker.sock ]; then
    # Docker socket exists, get its group ID
    docker_gid=$(stat -c '%g' /var/run/docker.sock 2>/dev/null)
    if [ -z "$docker_gid" ]; then
        echo -e "${RED}ERROR:${NC} Failed to get Docker socket GID. Permission denied?"
        exit 1
    fi
else
    # Fallback to docker group if socket doesn't exist
    docker_gid=$(getent group docker | cut -d: -f3)
    if [ -z "$docker_gid" ]; then
        echo -e "${RED}ERROR:${NC} Docker socket not found and Docker group not found. Please install Docker first."
        exit 1
    fi
    echo -e "${YELLOW}WARNING:${NC} Docker socket not found. Using docker group GID: $docker_gid"
fi

# Check if template files exist
if [ ! -f "docker-compose.yml.template" ]; then
    echo -e "${RED}ERROR:${NC} docker-compose.yml.template not found"
    exit 1
fi

if [ ! -f "Dockerfile.template" ]; then
    echo -e "${RED}ERROR:${NC} Dockerfile.template not found"
    exit 1
fi

if [ ! -f ".devcontainer/devcontainer.json.template" ]; then
    echo -e "${RED}ERROR:${NC} .devcontainer/devcontainer.json.template not found"
    exit 1
fi

if [ ! -f ".devcontainer/docker-compose.yml.template" ]; then
    echo -e "${RED}ERROR:${NC} .devcontainer/docker-compose.yml.template not found"
    exit 1
fi

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

# Generate docker-compose.yml and Dockerfile
echo "Generating docker-compose.yml..."
if [ "$setup_mode" = "1" ]; then
    # Normal mode: use existing template
    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
        docker-compose.yml.template > docker-compose.yml
else
    # Custom mode: use custom template
    sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
        docker-compose.custom.template > docker-compose.yml
fi

echo "Generating Dockerfile..."
if [ "$setup_mode" = "1" ]; then
    # Normal mode: use existing template
    cp Dockerfile.template Dockerfile
else
    # Custom mode: generate from custom template
    docker_install=$(generate_docker_install "$install_docker")
    aws_cli_install=$(generate_aws_cli_install "$install_aws_cli")

    # Generate python3 system package install (only for poetry)
    python3_install=$(generate_python3_install "$python_manager")

    # Generate Python manager installation
    python_install=""
    case "$python_manager" in
        "uv")
            python_install=$(generate_uv_install "uv")
            ;;
        "poetry")
            python_install=$(generate_poetry_install "poetry")
            ;;
        "pyenv-poetry")
            pyenv_inst=$(generate_pyenv_install "pyenv-poetry")
            poetry_inst=$(generate_poetry_install "pyenv-poetry")
            python_install="${pyenv_inst}

${poetry_inst}"
            ;;
        "mise")
            python_install=$(generate_mise_python_install "mise")
            ;;
        "none")
            python_install=""
            ;;
    esac

    # Generate Node.js manager installation
    nodejs_install=""
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
        "none")
            nodejs_install=""
            ;;
    esac

    # Use awk for better multiline handling
    awk -v docker_inst="$docker_install" \
        -v aws_inst="$aws_cli_install" \
        -v python3_inst="$python3_install" \
        -v python_inst="$python_install" \
        -v nodejs_inst="$nodejs_install" '
        /{{DOCKER_INSTALL}}/ { print docker_inst; next }
        /{{AWS_CLI_INSTALL}}/ { print aws_inst; next }
        /{{PYTHON3_INSTALL}}/ { print python3_inst; next }
        /{{PYTHON_MANAGER_INSTALL}}/ { print python_inst; next }
        /{{NODEJS_MANAGER_INSTALL}}/ { print nodejs_inst; next }
        { print }
    ' Dockerfile.custom.template > Dockerfile
fi

echo "Generating .devcontainer/devcontainer.json..."
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
    -e "s/{{USERNAME}}/$username/g" \
    .devcontainer/devcontainer.json.template > .devcontainer/devcontainer.json

echo "Generating .devcontainer/docker-compose.yml..."
# Service name must be static, but other values can use .env
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
    .devcontainer/docker-compose.yml.template > .devcontainer/docker-compose.yml

# Create .envs directory if it doesn't exist
mkdir -p .envs

# Generate .env file for this service
echo "Generating .envs/$container_service_name.env..."
cat > .envs/$container_service_name.env << EOF
# Environment variables for $container_service_name
# Generated on $(date)

CONTAINER_SERVICE_NAME=$container_service_name
USERNAME=$username
UID=$uid
GID=$gid
DOCKER_GID=$docker_gid
SETUP_MODE=$setup_mode
INSTALL_DOCKER=$install_docker
INSTALL_AWS_CLI=$install_aws_cli
PYTHON_MANAGER=$python_manager
NODEJS_MANAGER=$nodejs_manager
EOF

# Create symlink to .env for docker compose to use
# Using relative path to ensure portability across different environments
ln -sf .envs/$container_service_name.env .env

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $container_service_name"
echo "Username: $username"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Docker GID: $docker_gid (automatically detected)"
echo ""
if [ "$setup_mode" = "1" ]; then
    echo "Setup mode: Normal (Quick start)"
    echo "Software installed: Docker CLI, AWS CLI v2, uv, Volta (recommended for Python & Node.js development)"
else
    echo "Setup mode: Custom"
    echo "Software selected:"
    [ "$install_docker" = true ] && echo "  - Docker CLI: Yes" || echo "  - Docker CLI: No"
    [ "$install_aws_cli" = true ] && echo "  - AWS CLI v2: Yes" || echo "  - AWS CLI v2: No"
    echo "  - Python Manager: $python_manager"
    echo "  - Node.js Manager: $nodejs_manager"
fi
echo ""
echo "Generated files:"
echo "  - Dockerfile"
echo "  - docker-compose.yml"
echo "  - .devcontainer/devcontainer.json"
echo "  - .devcontainer/docker-compose.yml"
echo "  - .envs/$container_service_name.env (linked to .env)"
echo ""
echo "You can build the Docker image with the following command:"
echo -e "  ${YELLOW}docker compose${NC} build"
echo -e "  ${YELLOW}docker compose${NC} build --no-cache  ${CYAN}# to rebuild without cache${NC}"
echo ""
echo "To start the container:"
echo -e "  ${YELLOW}docker compose${NC} up ${CYAN}-d${NC}"
echo ""
echo "To access the container:"
echo -e "  ${YELLOW}docker compose${NC} exec $container_service_name bash"
echo ""
echo "To stop the container:"
echo -e "  ${YELLOW}docker compose${NC} down"