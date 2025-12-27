#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared generator functions
# shellcheck source=lib/generators.sh
source "$SCRIPT_DIR/lib/generators.sh"

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
install_aws_sam_cli=true
install_github_cli=true
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
            [Yy]*) install_docker=true; break ;;
            [Nn]*) install_docker=false; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter Y or n" ;;
        esac
    done

    # AWS CLI v2
    while true; do
        read -p "Install AWS CLI v2? [Y/n]: " choice
        choice=${choice:-Y}  # Default to Y if empty
        case $choice in
            [Yy]*) install_aws_cli=true; break ;;
            [Nn]*) install_aws_cli=false; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter Y or n" ;;
        esac
    done

    # AWS SAM CLI
    while true; do
        read -p "Install AWS SAM CLI? [Y/n]: " choice
        choice=${choice:-Y}  # Default to Y if empty
        case $choice in
            [Yy]*) install_aws_sam_cli=true; break ;;
            [Nn]*) install_aws_sam_cli=false; break ;;
            *) echo -e "${RED}ERROR:${NC} Please enter Y or n" ;;
        esac
    done

    # GitHub CLI
    while true; do
        read -p "Install GitHub CLI? [Y/n]: " choice
        choice=${choice:-Y}  # Default to Y if empty
        case $choice in
            [Yy]*) install_github_cli=true; break ;;
            [Nn]*) install_github_cli=false; break ;;
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

# Automatically get Docker socket GID using robust detection
docker_gid=$(detect_docker_gid)
if [ -z "$docker_gid" ]; then
    echo -e "${RED}ERROR:${NC} Failed to detect Docker GID."
    echo "Tried: /var/run/docker.sock, rootless socket, docker group"
    echo "Please ensure Docker is installed and running."
    exit 1
fi
echo -e "${GREEN}Detected Docker GID:${NC} $docker_gid"

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
    # Custom mode: generate from custom template using shared library function
    generate_dockerfile_from_template \
        "Dockerfile.custom.template" \
        "Dockerfile" \
        "$install_docker" \
        "$install_aws_cli" \
        "$install_aws_sam_cli" \
        "$install_github_cli" \
        "$python_manager" \
        "$nodejs_manager"
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
UBUNTU_VERSION=$UBUNTU_VERSION
SETUP_MODE=$setup_mode
INSTALL_DOCKER=$install_docker
INSTALL_AWS_CLI=$install_aws_cli
INSTALL_AWS_SAM_CLI=$install_aws_sam_cli
INSTALL_GITHUB_CLI=$install_github_cli
PYTHON_MANAGER=$python_manager
NODEJS_MANAGER=$nodejs_manager
EOF

# Create symlink to .env for docker compose to use
# Using relative path to ensure portability across different environments
ln -sf .envs/$container_service_name.env .env

# Verify symlink was created correctly
if ! validate_symlink ".env" ".envs/"; then
    echo -e "${RED}ERROR:${NC} Failed to create symlink to .envs/$container_service_name.env"
    exit 1
fi

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $container_service_name"
echo "Username: $username"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Docker GID: $docker_gid (automatically detected)"
echo ""
if [ "$setup_mode" = "1" ]; then
    echo "Setup mode: Normal (Quick start)"
    echo "Software installed: Docker CLI, AWS CLI v2, AWS SAM CLI, GitHub CLI, uv, Volta (recommended for Python & Node.js development)"
else
    echo "Setup mode: Custom"
    echo "Software selected:"
    [ "$install_docker" = true ] && echo "  - Docker CLI: Yes" || echo "  - Docker CLI: No"
    [ "$install_aws_cli" = true ] && echo "  - AWS CLI v2: Yes" || echo "  - AWS CLI v2: No"
    [ "$install_aws_sam_cli" = true ] && echo "  - AWS SAM CLI: Yes" || echo "  - AWS SAM CLI: No"
    [ "$install_github_cli" = true ] && echo "  - GitHub CLI: Yes" || echo "  - GitHub CLI: No"
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