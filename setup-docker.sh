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

# Automatically get UID and GID from current user
uid=$(id -u)
gid=$(id -g)

# Automatically get Docker socket GID (host's Docker group GID)
if [ -S /var/run/docker.sock ]; then
    # Docker socket exists, get its group ID
    docker_gid=$(stat -c '%g' /var/run/docker.sock)
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

# Generate docker-compose.yml and Dockerfile
echo "Generating docker-compose.yml..."
# Service name must be static, but other values can use .env
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
    docker-compose.yml.template > docker-compose.yml

echo "Generating Dockerfile..."
cp Dockerfile.template Dockerfile

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
EOF

# Create symlink to .env for docker compose to use
ln -sf .envs/$container_service_name.env .env

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $container_service_name"
echo "Username: $username"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Docker GID: $docker_gid (automatically detected)"
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