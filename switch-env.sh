#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

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
        for env_file in .envs/*.env; do
            if [ -f "$env_file" ]; then
                service_name=$(basename "$env_file" .env)
                echo -e "  ${CYAN}$service_name${NC}"
            fi
        done
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
ln -sf .envs/$container_service_name.env .env

echo -e "${GREEN}=== Environment Switched ===${NC}"
if [ -n "$current_env" ]; then
    echo "From: $current_env"
fi
echo "To:   $container_service_name"
echo ""
echo "Environment variables loaded from: .envs/$container_service_name.env"
echo ""
echo "To apply changes, rebuild and restart the container:"
echo -e "  ${YELLOW}docker compose down${NC}"
echo -e "  ${YELLOW}docker compose build --no-cache${NC}"
echo -e "  ${YELLOW}docker compose up -d${NC}"
echo ""
echo -e "${RED}IMPORTANT:${NC} Rebuild is required because USERNAME has changed"
