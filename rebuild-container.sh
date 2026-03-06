#!/bin/bash

# ============================================================
# rebuild-container.sh - No-cache Dev Container rebuild
# ============================================================
# Run from the host OS to rebuild the Docker image without cache
# and recreate/start the Dev Container.
#
# Cannot be run from inside a container.
#
# Usage: ./rebuild-container.sh
#
# Prerequisites:
#   - Docker is installed and running
#   - curl is installed (for devcontainer CLI auto-install)
# ============================================================

set -euo pipefail

# ===== Resolve Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR"
# ===== Load Shared Libraries =====
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/devcontainer.sh"
# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  echo -e "${RED}ERROR:${NC} This script cannot be run from inside a container"
  echo "  Please run from the host OS"
  exit 1
fi

echo ""
echo -e "${BOLD}========================================"
echo " No-cache Rebuild Script"
echo -e "========================================${NC}"
echo ""
echo -e "Workspace: ${BOLD}${WORKSPACE_DIR}${NC}"

# ============================================================
# Prerequisites Check (via lib/devcontainer.sh)
# ============================================================

check_all_prerequisites "$WORKSPACE_DIR"

# ============================================================
# Show Current Image Info
# ============================================================

echo ""

SERVICE_NAME=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORKSPACE_DIR/.env" || echo "dev")
WORKSPACE_NAME=$(basename "$WORKSPACE_DIR")
IMAGE_NAME="${WORKSPACE_NAME}-${SERVICE_NAME}"

if docker image inspect "$IMAGE_NAME" &>/dev/null; then
  CREATED_DATE=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' 2>/dev/null || true)
  if [[ -n "$CREATED_DATE" ]]; then
    CREATED_EPOCH=$(date -d "$CREATED_DATE" +%s 2>/dev/null || echo "0")
    CURRENT_EPOCH=$(date +%s)
    DAYS_OLD=$(( (CURRENT_EPOCH - CREATED_EPOCH) / 86400 ))
    FORMATTED_DATE=$(date -d "$CREATED_DATE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$CREATED_DATE")

    echo -e "Current image: ${BOLD}${IMAGE_NAME}${NC}"
    echo -e "Created:       ${BOLD}${FORMATTED_DATE}${NC} (${DAYS_OLD} days ago)"
  fi
else
  echo -e "Image ${BOLD}${IMAGE_NAME}${NC} not found (first build)"
fi

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}⚠ Notice:${NC}"
echo "  - The Docker image will be rebuilt without cache"
echo "  - The existing container will be deleted and recreated"
echo "  - The rebuild may take several minutes"
echo ""
read -rp "Proceed with rebuild? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelled"
  exit 0
fi

# ============================================================
# Rebuild & Start
# ============================================================

echo ""
echo -e "${CYAN}🔨 Rebuilding without cache & starting...${NC}"
echo -e "${YELLOW}   This may take several minutes${NC}"
echo ""

run_devcontainer up \
  --workspace-folder "$WORKSPACE_DIR" \
  --build-no-cache \
  --remove-existing-container

# ============================================================
# Done
# ============================================================

echo ""
echo -e "${GREEN}✅ Rebuild & startup complete${NC}"

# Show new image info
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
  NEW_DATE=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' 2>/dev/null || true)
  if [[ -n "$NEW_DATE" ]]; then
    NEW_FORMATTED=$(date -d "$NEW_DATE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$NEW_DATE")
    echo -e "New image created: ${BOLD}${NEW_FORMATTED}${NC}"
  fi
fi

echo ""
echo -e "${CYAN}📌 In VS Code, press Ctrl+Shift+P →${NC}"
echo -e "${CYAN}   'Dev Containers: Reopen in Container'${NC}"
echo ""
