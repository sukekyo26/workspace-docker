#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared libraries
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/certificates.sh
source "$SCRIPT_DIR/lib/certificates.sh"
# shellcheck source=lib/validators.sh
source "$SCRIPT_DIR/lib/validators.sh"
# shellcheck source=lib/generators.sh
source "$SCRIPT_DIR/lib/generators.sh"
# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"

trap tui_cleanup EXIT

# ============================================================
# Parse arguments
# ============================================================
FORCE_INIT=false
AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    --init) FORCE_INIT=true ;;
    --yes|-y) AUTO_YES=true ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

# ============================================================
# Prerequisites
# ============================================================
check_uv || exit 1

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

  if [[ "$AUTO_YES" = true ]]; then
    # Non-interactive: use sensible defaults
    container_service_name="dev"
    username="$(whoami)"
    info "Service name: $container_service_name (default)"
    info "Username: $username (current user)"
  else
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
  fi

  # Software installation selection
  subsection_header "Software Installation Selection"

  # Dynamic plugin selection from plugins/ directory
  list_available_plugins
  local_enabled_plugins=()

  if [[ "$AUTO_YES" = true ]]; then
    # Non-interactive: select plugins marked as default
    for ((i = 0; i < ${#PLUGIN_IDS[@]}; i++)); do
      plugin_id="${PLUGIN_IDS[$i]}"
      plugin_default="${PLUGIN_DEFAULTS[$i]}"
      if [[ "$plugin_default" == "true" ]]; then
        local_enabled_plugins+=("$plugin_id")
        info "  ${plugin_id}: enabled (default)"
      else
        info "  ${plugin_id}: skipped"
      fi
    done
  else
    # Build preselected CSV from plugin defaults
    preselected_csv=""
    for ((i = 0; i < ${#PLUGIN_IDS[@]}; i++)); do
      if [[ "${PLUGIN_DEFAULTS[$i]}" == "true" ]]; then
        [[ -n "$preselected_csv" ]] && preselected_csv+=","
        preselected_csv+="$i"
      fi
    done

    # TUI multi-select for plugins
    select_multi "Select plugins to install:" "$preselected_csv" "${PLUGIN_NAMES[@]}" || {
      echo "キャンセルしました" >&2
      exit 0
    }

    for idx in "${TUI_MULTI_RESULT[@]}"; do
      local_enabled_plugins+=("${PLUGIN_IDS[$idx]}")
    done
  fi

  # Port forwarding
  if [[ "$AUTO_YES" = true ]]; then
    forward_port=3000
    info "Forward port: $forward_port (default)"
  else
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
  fi

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

  # Preserve [apt], [vscode], [volumes] from existing workspace.toml
  # This allows users to pre-define these sections before running --init
  apt_toml="packages = []"
  vscode_toml="extensions = []"
  volumes_toml=""
  if [[ -f "$WORKSPACE_TOML" ]]; then
    load_workspace_config "$WORKSPACE_TOML"

    # Rebuild [apt] packages
    if [[ ${#WS_APT_EXTRA[@]} -gt 0 && -n "${WS_APT_EXTRA[0]}" ]]; then
      apt_toml="packages = ["
      for ((i = 0; i < ${#WS_APT_EXTRA[@]}; i++)); do
        [[ $i -gt 0 ]] && apt_toml+=", "
        apt_toml+="\"${WS_APT_EXTRA[$i]}\""
      done
      apt_toml+="]"
    fi

    # Rebuild [vscode] extensions
    if [[ ${#WS_VSCODE_EXTENSIONS[@]} -gt 0 && -n "${WS_VSCODE_EXTENSIONS[0]}" ]]; then
      vscode_toml=$'extensions = [\n'
      for ((i = 0; i < ${#WS_VSCODE_EXTENSIONS[@]}; i++)); do
        vscode_toml+="  \"${WS_VSCODE_EXTENSIONS[$i]}\""
        if [[ $i -lt $((${#WS_VSCODE_EXTENSIONS[@]} - 1)) ]]; then
          vscode_toml+=","
        fi
        vscode_toml+=$'\n'
      done
      vscode_toml+="]"
    fi

    # Rebuild [volumes]
    if [[ ${#WS_VOLUME_NAMES[@]} -gt 0 && -n "${WS_VOLUME_NAMES[0]}" ]]; then
      for ((i = 0; i < ${#WS_VOLUME_NAMES[@]}; i++)); do
        volumes_toml+="${WS_VOLUME_NAMES[$i]} = \"${WS_VOLUME_PATHS[$i]}\""$'\n'
      done
    fi
  fi

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

[apt]
$apt_toml

[vscode]
$vscode_toml

[volumes]
$volumes_toml
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



# ============================================================
# File generation
# ============================================================
echo "Generating docker-compose.yml..."
generate_compose \
  "docker-compose.yml" \
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
  "Dockerfile" \
  "$WORKSPACE_TOML"

echo "Generating .devcontainer/devcontainer.json..."
generate_devcontainer_json \
  ".devcontainer/devcontainer.json" \
  "$WORKSPACE_TOML"

echo "Generating .devcontainer/docker-compose.yml..."
generate_devcontainer_compose \
  ".devcontainer/docker-compose.yml" \
  "$WORKSPACE_TOML"

# Generate .env file for docker-compose
echo "Generating .env..."
{
  cat << 'EOF'
# Environment variables for docker-compose
# Auto-generated from workspace.toml — do not edit manually
# Regenerate with: ./setup-docker.sh

EOF
  printf 'COMPOSE_PROJECT_NAME=%s\n' "$(basename "$SCRIPT_DIR")"
  printf 'CONTAINER_SERVICE_NAME=%s\n' "$WS_SERVICE_NAME"
  printf 'USERNAME=%s\n' "$WS_USERNAME"
  printf 'UID=%s\n' "$uid"
  printf 'GID=%s\n' "$gid"
  printf 'DOCKER_GID=%s\n' "$docker_gid"
  printf 'UBUNTU_VERSION=%s\n' "$WS_UBUNTU_VERSION"
  printf 'FORWARD_PORT=%s\n' "${WS_FORWARD_PORTS[0]:-3000}"
} > ".env"
chmod 600 ".env"

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
echo -e "  Or run ${YELLOW}./setup-docker.sh --init --yes${NC} for non-interactive setup with defaults"
