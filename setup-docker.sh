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

# Set container service name
read -p "Enter container service name: " container_service_name

# Set username
read -p "Enter Ubuntu on Docker username: " username

# Automatically get UID and GID from current user
uid=$(id -u)
gid=$(id -g)

# Check if template files exist
if [ ! -f "docker-compose.yml.template" ]; then
    echo -e "${RED}ERROR:${NC} docker-compose.yml.template not found"
    exit 1
fi

if [ ! -f "Dockerfile.template" ]; then
    echo -e "${RED}ERROR:${NC} Dockerfile.template not found"
    exit 1
fi

# Generate docker-compose.yml and Dockerfile
echo "Generating docker-compose.yml..."
sed -e "s/{{CONTAINER_SERVICE_NAME}}/$container_service_name/g" \
    -e "s/{{USERNAME}}/$username/g" \
    -e "s/{{UID}}/$uid/g" \
    -e "s/{{GID}}/$gid/g" \
    docker-compose.yml.template > docker-compose.yml

echo "Generating Dockerfile..."
cp Dockerfile.template Dockerfile

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $container_service_name"
echo "Username: $username"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Dockerfile and docker-compose.yml have been generated"
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