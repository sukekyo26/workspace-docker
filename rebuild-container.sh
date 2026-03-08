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
source "$SCRIPT_DIR/lib/devcontainer.sh"
# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  die "$(msg rebuild_inside_container)"
fi

echo ""
echo -e "${BOLD}========================================"
echo " $(msg rebuild_header)"
echo -e "========================================${NC}"
echo ""
echo -e "$(msg rebuild_workspace) ${BOLD}${WORKSPACE_DIR}${NC}"

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

    echo -e "$(msg rebuild_current_image "${BOLD}${IMAGE_NAME}${NC}")"
    echo -e "$(msg rebuild_created "${BOLD}${FORMATTED_DATE}${NC}" "${DAYS_OLD}")"
  fi
else
  echo -e "$(msg rebuild_image_not_found "${BOLD}${IMAGE_NAME}${NC}")"
fi

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}$(msg rebuild_notice)${NC}"
msgln rebuild_notice_1
msgln rebuild_notice_2
msgln rebuild_notice_3
echo ""
read -rp "$(msg rebuild_confirm)" confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  msgln rebuild_cancelled
  exit 0
fi

# ============================================================
# Rebuild & Start
# ============================================================

echo ""
echo -e "${CYAN}$(msg rebuild_starting)${NC}"
echo -e "${YELLOW}$(msg rebuild_please_wait)${NC}"
echo ""

run_devcontainer up \
  --workspace-folder "$WORKSPACE_DIR" \
  --build-no-cache \
  --remove-existing-container

# ============================================================
# Done
# ============================================================

echo ""
echo -e "${GREEN}$(msg rebuild_complete)${NC}"

# Show new image info
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
  NEW_DATE=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' 2>/dev/null || true)
  if [[ -n "$NEW_DATE" ]]; then
    NEW_FORMATTED=$(date -d "$NEW_DATE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$NEW_DATE")
    echo -e "$(msg rebuild_new_image "${BOLD}${NEW_FORMATTED}${NC}")"
  fi
fi

echo ""
echo -e "${CYAN}$(msg rebuild_vscode_1)${NC}"
echo -e "${CYAN}$(msg rebuild_vscode_2)${NC}"
echo ""
