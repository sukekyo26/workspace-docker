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

# Validate existing .env symlink if present
if [ -L ".env" ]; then
    if ! validate_symlink ".env" ".envs/"; then
        echo -e "${YELLOW}WARNING:${NC} Current .env symlink is broken, will be replaced"
    fi
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

# Verify symlink was created correctly
if ! validate_symlink ".env" ".envs/"; then
    echo -e "${RED}ERROR:${NC} Failed to create symlink to .envs/$container_service_name.env"
    exit 1
fi

# Read environment variables from the new .env file using safe parser
CONTAINER_SERVICE_NAME=$(read_env_var "CONTAINER_SERVICE_NAME" ".env")
USERNAME_ENV=$(read_env_var "USERNAME" ".env")
SETUP_MODE=$(read_env_var "SETUP_MODE" ".env")
INSTALL_DOCKER=$(read_env_var "INSTALL_DOCKER" ".env")
INSTALL_AWS_CLI=$(read_env_var "INSTALL_AWS_CLI" ".env")
INSTALL_AWS_SAM_CLI=$(read_env_var "INSTALL_AWS_SAM_CLI" ".env")
INSTALL_GITHUB_CLI=$(read_env_var "INSTALL_GITHUB_CLI" ".env")
PYTHON_MANAGER=$(read_env_var "PYTHON_MANAGER" ".env")
NODEJS_MANAGER=$(read_env_var "NODEJS_MANAGER" ".env")

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
    # Custom mode: generate with selected tools using shared library function
    # Default to false/none if variables are empty
    [ -z "$INSTALL_DOCKER" ] && INSTALL_DOCKER=false
    [ -z "$INSTALL_AWS_CLI" ] && INSTALL_AWS_CLI=false
    [ -z "$INSTALL_AWS_SAM_CLI" ] && INSTALL_AWS_SAM_CLI=false
    [ -z "$INSTALL_GITHUB_CLI" ] && INSTALL_GITHUB_CLI=false
    [ -z "$PYTHON_MANAGER" ] && PYTHON_MANAGER="none"
    [ -z "$NODEJS_MANAGER" ] && NODEJS_MANAGER="none"

    generate_dockerfile_from_template \
        "Dockerfile.custom.template" \
        "Dockerfile" \
        "$INSTALL_DOCKER" \
        "$INSTALL_AWS_CLI" \
        "$INSTALL_AWS_SAM_CLI" \
        "$INSTALL_GITHUB_CLI" \
        "$PYTHON_MANAGER" \
        "$NODEJS_MANAGER"
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
