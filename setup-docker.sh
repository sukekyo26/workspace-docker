#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared libraries
# shellcheck source=lib/generators.sh
source "$SCRIPT_DIR/lib/generators.sh"
# shellcheck source=lib/validators.sh
source "$SCRIPT_DIR/lib/validators.sh"
# shellcheck source=lib/errors.sh
source "$SCRIPT_DIR/lib/errors.sh"

section_header "Generate Dockerfile for Ubuntu on Docker"

# Check if ~/.gitconfig exists
if [ ! -f "$HOME/.gitconfig" ]; then
    die_with_hint "$HOME/.gitconfig not found" "Please configure Git first:\n  git config --global user.name \"Your Name\"\n  git config --global user.email \"your.email@example.com\""
fi

# Set container service name
while true; do
    read -rp "Enter container service name: " container_service_name

    if validate_service_name "$container_service_name" 2>&1; then
        break
    fi
done

# Set username
while true; do
    read -rp "Enter Ubuntu on Docker username: " username

    if validate_username "$username" 2>&1; then
        break
    fi
done

# Software installation selection
subsection_header "Software Installation Selection"
echo "proto is always installed (multi-language version manager)"
echo ""

# Initialize software installation flags
install_docker=true
install_aws_cli=true
install_aws_sam_cli=true
install_github_cli=true
install_zig=true

# Docker CLI
while true; do
    read -rp "Install Docker CLI? [Y/n]: " choice
    choice=${choice:-Y}  # Default to Y if empty
    case $choice in
        [Yy]*) install_docker=true; break ;;
        [Nn]*) install_docker=false; break ;;
        *) error "Please enter Y or n" ;;
    esac
done

# AWS CLI v2
while true; do
    read -rp "Install AWS CLI v2? [Y/n]: " choice
    choice=${choice:-Y}  # Default to Y if empty
    case $choice in
        [Yy]*) install_aws_cli=true; break ;;
        [Nn]*) install_aws_cli=false; break ;;
        *) error "Please enter Y or n" ;;
    esac
done

# AWS SAM CLI
while true; do
    read -rp "Install AWS SAM CLI? [Y/n]: " choice
    choice=${choice:-Y}  # Default to Y if empty
    case $choice in
        [Yy]*) install_aws_sam_cli=true; break ;;
        [Nn]*) install_aws_sam_cli=false; break ;;
        *) error "Please enter Y or n" ;;
    esac
done

# GitHub CLI
while true; do
    read -rp "Install GitHub CLI? [Y/n]: " choice
    choice=${choice:-Y}  # Default to Y if empty
    case $choice in
        [Yy]*) install_github_cli=true; break ;;
        [Nn]*) install_github_cli=false; break ;;
        *) error "Please enter Y or n" ;;
    esac
done

# Zig
while true; do
    read -rp "Install Zig (required for cargo-lambda)? [Y/n]: " choice
    choice=${choice:-Y}  # Default to Y if empty
    case $choice in
        [Yy]*) install_zig=true; break ;;
        [Nn]*) install_zig=false; break ;;
        *) error "Please enter Y or n" ;;
    esac
done

# Automatically get UID and GID from current user
uid=$(id -u)
gid=$(id -g)

# Automatically get Docker socket GID using robust detection
docker_gid=$(detect_docker_gid)
if [ -z "$docker_gid" ]; then
    die_with_hint "Failed to detect Docker GID" "Tried: /var/run/docker.sock, rootless socket, docker group\nPlease ensure Docker is installed and running"
fi
success "Detected Docker GID: $docker_gid"

# Check if template files exist
validate_file_exists "docker-compose.yml.template" "docker-compose.yml.template" || exit 1
validate_file_exists "Dockerfile.template" "Dockerfile.template" || exit 1
validate_file_exists ".devcontainer/devcontainer.json.template" ".devcontainer/devcontainer.json.template" || exit 1
validate_file_exists ".devcontainer/docker-compose.yml.template" ".devcontainer/docker-compose.yml.template" || exit 1

# Generate docker-compose.yml and Dockerfile
echo "Generating docker-compose.yml..."
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
    docker-compose.yml.template > docker-compose.yml

echo "Generating Dockerfile..."

# Check for custom CA certificates in certs/ directory
if has_valid_certificates; then
    subsection_header "Custom CA Certificates Detected"
    echo "The following certificates will be installed from certs/:"
    while IFS= read -r cert; do
        info "  $cert"
    done <<< "$(list_valid_certificates)"
    echo ""
fi

generate_dockerfile_from_template \
    "Dockerfile.template" \
    "Dockerfile" \
    "$install_docker" \
    "$install_aws_cli" \
    "$install_aws_sam_cli" \
    "$install_github_cli" \
    "$install_zig"

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
cat > ".envs/${container_service_name}.env" << EOF
# Environment variables for $container_service_name
# Generated on $(date)

CONTAINER_SERVICE_NAME=$container_service_name
USERNAME=$username
UID=$uid
GID=$gid
DOCKER_GID=$docker_gid
UBUNTU_VERSION=$UBUNTU_VERSION
INSTALL_DOCKER=$install_docker
INSTALL_AWS_CLI=$install_aws_cli
INSTALL_AWS_SAM_CLI=$install_aws_sam_cli
INSTALL_GITHUB_CLI=$install_github_cli
INSTALL_ZIG=$install_zig
EOF

# Create symlink to .env for docker compose to use
# Using relative path to ensure portability across different environments
ln -sf ".envs/${container_service_name}.env" .env

# Verify symlink was created correctly
if ! validate_symlink ".env" ".envs/"; then
    die "Failed to create symlink to .envs/$container_service_name.env"
fi

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $container_service_name"
echo "Username: $username"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Docker GID: $docker_gid (automatically detected)"
echo ""
echo "Software installed:"
echo "  - proto: Yes (always installed)"
[ "$install_docker" = true ] && echo "  - Docker CLI: Yes" || echo "  - Docker CLI: No"
[ "$install_aws_cli" = true ] && echo "  - AWS CLI v2: Yes" || echo "  - AWS CLI v2: No"
[ "$install_aws_sam_cli" = true ] && echo "  - AWS SAM CLI: Yes" || echo "  - AWS SAM CLI: No"
[ "$install_github_cli" = true ] && echo "  - GitHub CLI: Yes" || echo "  - GitHub CLI: No"
[ "$install_zig" = true ] && echo "  - Zig: Yes" || echo "  - Zig: No"
has_valid_certificates && echo "  - Custom CA Certificates: Yes (from certs/)"
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
