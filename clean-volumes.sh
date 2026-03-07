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

# ===== Load Shared Libraries =====
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  die "This script cannot be run from inside a container"
fi

echo ""
echo -e "${BOLD}========================================"
echo " Docker Volume Cleanup Script"
echo -e "========================================${NC}"
echo ""
echo -e "Workspace: ${BOLD}${WORKSPACE_DIR}${NC}"

# ============================================================
# Prerequisites Check
# ============================================================

if ! command -v docker &>/dev/null; then
  die "docker command not found"
fi

if ! docker info &>/dev/null; then
  die "Docker daemon is not running"
fi

# ============================================================
# Detect Project Volumes
# ============================================================

SERVICE_NAME=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORKSPACE_DIR/.env" || echo "dev")
PROJECT_NAME=$(read_env_var "COMPOSE_PROJECT_NAME" "$WORKSPACE_DIR/.env" || basename "$WORKSPACE_DIR")
VOLUME_PREFIX="${PROJECT_NAME}_${SERVICE_NAME}_"

echo ""
echo -e "Project name:   ${BOLD}${PROJECT_NAME}${NC}"
echo -e "Service name:   ${BOLD}${SERVICE_NAME}${NC}"
echo -e "Volume prefix:  ${BOLD}${VOLUME_PREFIX}${NC}"
echo ""

# Find volumes matching the project prefix
mapfile -t volumes < <(docker volume ls --format '{{.Name}}' | grep "^${VOLUME_PREFIX}" 2>/dev/null || true)

if [[ ${#volumes[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No volumes found to delete${NC}"
  echo "  Prefix: ${VOLUME_PREFIX}"
  exit 0
fi

echo -e "${CYAN}Volumes to delete (${#volumes[@]}):${NC}"
for vol in "${volumes[@]}"; do
  echo "  - $vol"
done

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}⚠ Notice:${NC}"
echo "  - All volumes listed above will be deleted"
echo "  - Data in volumes cannot be recovered"
echo "  - Stop running containers first"
echo ""
read -rp "Proceed with deletion? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelled"
  exit 0
fi

# ============================================================
# Stop Containers if Running
# ============================================================

if docker compose -f "$WORKSPACE_DIR/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
  echo ""
  echo -e "${CYAN}Stopping containers...${NC}"
  docker compose -f "$WORKSPACE_DIR/docker-compose.yml" down 2>/dev/null || true
fi

# ============================================================
# Delete Volumes
# ============================================================

echo ""
echo -e "${CYAN}Deleting volumes...${NC}"

failed=0
for vol in "${volumes[@]}"; do
  if docker volume rm "$vol" 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $vol"
  else
    echo -e "  ${RED}❌${NC} $vol (deletion failed — may be in use)"
    failed=$((failed + 1))
  fi
done

# ============================================================
# Done
# ============================================================

echo ""
if [[ "$failed" -eq 0 ]]; then
  echo -e "${GREEN}✅ All ${#volumes[@]} volumes deleted successfully${NC}"
else
  echo -e "${YELLOW}⚠ $((${#volumes[@]} - failed)) deleted, ${failed} failed${NC}"
  exit 1
fi
