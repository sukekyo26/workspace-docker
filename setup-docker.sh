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

# ============================================================
# Parse arguments
# ============================================================
FORCE_INIT=false
for arg in "$@"; do
    case "$arg" in
        --init) FORCE_INIT=true ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

# ============================================================
# Prerequisites
# ============================================================
check_python3 || exit 1

WORKSPACE_TOML="$SCRIPT_DIR/workspace.toml"

# ============================================================
# Mode: Regenerate (workspace.toml exists and not --init)
# ============================================================
if [[ -f "$WORKSPACE_TOML" && "$FORCE_INIT" = false ]]; then
    section_header "Regenerate from workspace.toml"

    load_workspace_config "$WORKSPACE_TOML"

    info "Service: $WS_SERVICE_NAME"
    info "Username: $WS_USERNAME"
    info "Plugins: ${WS_PLUGINS[*]}"
else
    # ============================================================
    # Mode: Interactive setup (first run or --init)
    # ============================================================
    section_header "Generate Dockerfile for Ubuntu on Docker"

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
    echo ""

    # Dynamic plugin selection from plugins/ directory
    list_available_plugins
    local_enabled_plugins=()

    for ((i = 0; i < ${#PLUGIN_IDS[@]}; i++)); do
        plugin_id="${PLUGIN_IDS[$i]}"
        plugin_name="${PLUGIN_NAMES[$i]}"
        plugin_default="${PLUGIN_DEFAULTS[$i]}"

        if [[ "$plugin_default" == "true" ]]; then
            prompt_default="Y/n"
            default_choice="Y"
        else
            prompt_default="y/N"
            default_choice="N"
        fi

        while true; do
            read -rp "Install ${plugin_name}? [${prompt_default}]: " choice
            choice=${choice:-$default_choice}
            case $choice in
                [Yy]*) local_enabled_plugins+=("$plugin_id"); break ;;
                [Nn]*) break ;;
                *) error "Please enter Y or n" ;;
            esac
        done
    done

    # Port forwarding
    subsection_header "Port Configuration"
    while true; do
        read -rp "Forward port [3000]: " forward_port
        forward_port=${forward_port:-3000}
        if [[ "$forward_port" =~ ^[0-9]+$ ]] && [ "$forward_port" -ge 1 ] && [ "$forward_port" -le 65535 ]; then
            break
        else
            error "Please enter a valid port number (1-65535)"
        fi
    done

    # Generate workspace.toml
    echo "Generating workspace.toml..."

    # Build plugins enable list for TOML
    plugins_toml="["
    for ((i = 0; i < ${#local_enabled_plugins[@]}; i++)); do
        if [[ $i -gt 0 ]]; then
            plugins_toml+=", "
        fi
        plugins_toml+="\"${local_enabled_plugins[$i]}\""
    done
    plugins_toml+="]"

    cat > "$WORKSPACE_TOML" << EOF
# workspace.toml — workspace-docker configuration
# Edit this file and run setup-docker.sh to regenerate

[container]
service_name = "$container_service_name"
username = "$username"
ubuntu_version = "24.04"

[plugins]
enable = $plugins_toml

[ports]
forward = [$forward_port]
EOF

    # Reload to set WS_* variables
    load_workspace_config "$WORKSPACE_TOML"
fi

# ============================================================
# Auto-detection
# ============================================================
uid=$(id -u)
gid=$(id -g)

docker_gid=$(detect_docker_gid)
if [ -z "$docker_gid" ]; then
    die_with_hint "Failed to detect Docker GID" "Tried: /var/run/docker.sock, rootless socket, docker group\nPlease ensure Docker is installed and running"
fi
success "Detected Docker GID: $docker_gid"

# ============================================================
# Template file validation
# ============================================================
validate_no_duplicate_apt_packages \
    "$SCRIPT_DIR/config/apt-base-packages.conf" \
    "${WS_APT_EXTRA[@]}" || true

validate_file_exists "docker-compose.yml.template" "docker-compose.yml.template" || exit 1
validate_file_exists "Dockerfile.template" "Dockerfile.template" || exit 1
validate_file_exists ".devcontainer/devcontainer.json.template" ".devcontainer/devcontainer.json.template" || exit 1
validate_file_exists ".devcontainer/docker-compose.yml.template" ".devcontainer/docker-compose.yml.template" || exit 1

# ============================================================
# File generation
# ============================================================
echo "Generating docker-compose.yml..."
generate_compose_from_template \
    "docker-compose.yml.template" \
    "docker-compose.yml" \
    "$WS_SERVICE_NAME" \
    "$WORKSPACE_TOML"

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
    "$WORKSPACE_TOML"

echo "Generating .devcontainer/devcontainer.json..."
generate_devcontainer_json_from_template \
    ".devcontainer/devcontainer.json.template" \
    ".devcontainer/devcontainer.json" \
    "$WS_SERVICE_NAME" \
    "$WS_USERNAME" \
    "${WS_FORWARD_PORTS[0]:-3000}"

echo "Generating .devcontainer/docker-compose.yml..."
generate_devcontainer_compose_from_template \
    ".devcontainer/docker-compose.yml.template" \
    ".devcontainer/docker-compose.yml" \
    "$WS_SERVICE_NAME"

# Generate .env file for docker-compose
echo "Generating .env..."
cat > ".env" << EOF
# Environment variables for docker-compose
# Auto-generated from workspace.toml — do not edit manually
# Regenerate with: ./setup-docker.sh

CONTAINER_SERVICE_NAME=$WS_SERVICE_NAME
USERNAME=$WS_USERNAME
UID=$uid
GID=$gid
DOCKER_GID=$docker_gid
UBUNTU_VERSION=$WS_UBUNTU_VERSION
FORWARD_PORT=${WS_FORWARD_PORTS[0]:-3000}
EOF

# Copy .bashrc_custom skeleton if not exists
if [[ ! -f "config/.bashrc_custom" && -f "config/.bashrc_custom.example" ]]; then
    cp "config/.bashrc_custom.example" "config/.bashrc_custom"
    echo "Created config/.bashrc_custom from example"
fi

# ============================================================
# Result display
# ============================================================
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Container service name: $WS_SERVICE_NAME"
echo "Username: $WS_USERNAME"
echo "UID/GID: $uid/$gid (automatically detected)"
echo "Docker GID: $docker_gid (automatically detected)"
echo ""
echo "Enabled plugins:"
for plugin_id in "${WS_PLUGINS[@]}"; do
    echo "  - ${plugin_id}: Yes"
done
has_valid_certificates && echo "  - Custom CA Certificates: Yes (from certs/)"
echo ""
echo "Port forwarding: ${WS_FORWARD_PORTS[0]:-3000}"
echo ""
echo "Generated files:"
echo "  - workspace.toml (configuration — edit this file)"
echo "  - Dockerfile"
echo "  - docker-compose.yml"
echo "  - .devcontainer/devcontainer.json"
echo "  - .devcontainer/docker-compose.yml"
echo "  - .env (auto-generated from workspace.toml)"
echo ""
echo "You can build the Docker image with the following command:"
echo -e "  ${YELLOW}docker compose${NC} build"
echo -e "  ${YELLOW}docker compose${NC} build --no-cache  ${CYAN}# to rebuild without cache${NC}"
echo ""
echo "To start the container:"
echo -e "  ${YELLOW}docker compose${NC} up ${CYAN}-d${NC}"
echo ""
echo "To access the container:"
echo -e "  ${YELLOW}docker compose${NC} exec $WS_SERVICE_NAME bash"
echo ""
echo "To stop the container:"
echo -e "  ${YELLOW}docker compose${NC} down"
echo ""
echo "To reconfigure:"
echo -e "  Edit ${YELLOW}workspace.toml${NC} and run ${YELLOW}./setup-docker.sh${NC}"
echo -e "  Or run ${YELLOW}./setup-docker.sh --init${NC} for interactive setup"
