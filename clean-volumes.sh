#!/bin/bash

# ============================================================
# clean-volumes.sh - Delete all Docker volumes for this project
# ============================================================
# Run from the host OS to delete all Docker named volumes
# associated with this project.
#
# Cannot be run from inside a container.
#
# Usage: ./clean-volumes.sh
#
# Prerequisites:
#   - Docker is installed and running
# ============================================================

set -euo pipefail

# ===== Resolve Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR"
# Pre-parse --lang option (must be set before i18n.sh is loaded)
_prev=""
for _arg in "$@"; do
  if [[ "$_prev" == "--lang" ]]; then
    export WORKSPACE_LANG="$_arg"
  fi
  _prev="$_arg"
done
unset _arg _prev
# ===== Load Shared Libraries =====
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  die "$(msg clean_inside_container)"
fi

echo ""
echo -e "${BOLD}========================================"
echo " $(msg clean_header)"
echo -e "========================================${NC}"
echo ""
echo -e "$(msg clean_workspace) ${BOLD}${WORKSPACE_DIR}${NC}"

# ============================================================
# Prerequisites Check
# ============================================================

if ! command -v docker &>/dev/null; then
  die "$(msg clean_docker_not_found)"
fi

if ! docker info &>/dev/null; then
  die "$(msg clean_docker_not_running)"
fi

# ============================================================
# Detect Project Volumes
# ============================================================

SERVICE_NAME=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORKSPACE_DIR/.env" || echo "dev")
PROJECT_NAME=$(read_env_var "COMPOSE_PROJECT_NAME" "$WORKSPACE_DIR/.env" || basename "$WORKSPACE_DIR")
VOLUME_PREFIX="${PROJECT_NAME}_${SERVICE_NAME}_"

echo ""
echo -e "$(msg clean_project_name)   ${BOLD}${PROJECT_NAME}${NC}"
echo -e "$(msg clean_service_name)   ${BOLD}${SERVICE_NAME}${NC}"
echo -e "$(msg clean_volume_prefix)  ${BOLD}${VOLUME_PREFIX}${NC}"
echo ""

# Find volumes matching the project prefix
mapfile -t volumes < <(docker volume ls --format '{{.Name}}' | grep "^${VOLUME_PREFIX}" 2>/dev/null || true)

if [[ ${#volumes[@]} -eq 0 ]]; then
  echo -e "${YELLOW}$(msg clean_no_volumes)${NC}"
  echo "  $(msg clean_prefix_info "$VOLUME_PREFIX")"
  exit 0
fi

echo -e "${CYAN}$(msg clean_volumes_header "${#volumes[@]}")${NC}"
for vol in "${volumes[@]}"; do
  echo "  - $vol"
done

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}$(msg clean_notice)${NC}"
msgln clean_notice_1
msgln clean_notice_2
msgln clean_notice_3
echo ""
read -rp "$(msg clean_confirm)" confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  msgln clean_cancelled
  exit 0
fi

# ============================================================
# Stop Containers if Running
# ============================================================

# Use project label to find containers (handles devcontainer-managed containers
# that are started with additional temporary compose files)
mapfile -t running_containers < <(docker ps -q --filter "label=com.docker.compose.project=${PROJECT_NAME}" 2>/dev/null || true)
if [[ ${#running_containers[@]} -gt 0 && -n "${running_containers[0]}" ]]; then
  echo ""
  echo -e "${CYAN}$(msg clean_stopping)${NC}"
  docker stop "${running_containers[@]}" 2>/dev/null || true
  docker rm "${running_containers[@]}" 2>/dev/null || true
fi

# ============================================================
# Delete Volumes
# ============================================================

echo ""
echo -e "${CYAN}$(msg clean_deleting)${NC}"

failed=0
for vol in "${volumes[@]}"; do
  if docker volume rm "$vol" 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $vol"
  else
    echo -e "  ${RED}❌${NC} $(msg clean_vol_failed "$vol")"
    failed=$((failed + 1))
  fi
done

# ============================================================
# Done
# ============================================================

# Remove associated Docker images (including devcontainer-generated images)
mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "^(vsc-.*${PROJECT_NAME}|${PROJECT_NAME}-${SERVICE_NAME}):" 2>/dev/null || true)
if [[ ${#images[@]} -gt 0 && -n "${images[0]}" ]]; then
  echo ""
  echo -e "${CYAN}$(msg clean_removing_images "${#images[@]}")${NC}"
  for img in "${images[@]}"; do
    if docker rmi "$img" 2>/dev/null; then
      echo -e "  ${GREEN}✅${NC} $img"
    else
      echo -e "  ${RED}❌${NC} $(msg clean_image_failed "$img")"
    fi
  done
fi

echo ""
if [[ "$failed" -eq 0 ]]; then
  echo -e "${GREEN}$(msg clean_all_deleted "${#volumes[@]}")${NC}"
else
  echo -e "${YELLOW}$(msg clean_partial "$((${#volumes[@]} - failed))" "$failed")${NC}"
  exit 1
fi
