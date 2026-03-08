#!/bin/bash

# ============================================================
# clean-docker.sh - Interactive Docker resource cleanup
# ============================================================
# Run from the host OS to remove unused Docker resources
# (stopped containers, build cache, dangling images, networks,
# volumes) using an interactive multi-select menu.
#
# Cannot be run from inside a container.
#
# Usage: ./clean-docker.sh [--lang <en|ja>]
#
# Prerequisites:
#   - Docker is installed and running
# ============================================================

set -euo pipefail

# ===== Resolve Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

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
source "$SCRIPT_DIR/lib/tui.sh"

trap tui_cleanup EXIT

# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  die "$(msg docker_clean_inside_container)"
fi

echo ""
echo -e "${BOLD}========================================"
echo " $(msg docker_clean_header)"
echo -e "========================================${NC}"
echo ""

# ============================================================
# Prerequisites Check
# ============================================================

if ! command -v docker &>/dev/null; then
  die "$(msg docker_clean_not_found)"
fi

if ! docker info &>/dev/null; then
  die "$(msg docker_clean_not_running)"
fi

# ============================================================
# Show Current Disk Usage
# ============================================================

echo -e "${CYAN}$(msg docker_clean_disk_usage)${NC}"
echo ""
docker system df
echo ""

# ============================================================
# Interactive Selection
# ============================================================

# Cleanup operations (order matters: containers first, then cache/images, then networks/volumes)
CLEANUP_OPTIONS=(
  "$(msg docker_clean_opt_containers)"
  "$(msg docker_clean_opt_builder)"
  "$(msg docker_clean_opt_images)"
  "$(msg docker_clean_opt_networks)"
  "$(msg docker_clean_opt_volumes)"
)

# Default: containers, builder cache, images ON; networks, volumes OFF
PRESELECTED="0,1,2"

select_multi "$(msg docker_clean_select_title)" "$PRESELECTED" "${CLEANUP_OPTIONS[@]}" || {
  msgln docker_clean_cancelled
  exit 0
}

if [[ ${#TUI_MULTI_RESULT[@]} -eq 0 ]]; then
  msgln docker_clean_cancelled
  exit 0
fi

echo ""

# ============================================================
# Execute Selected Cleanup Operations
# ============================================================

success_count=0
fail_count=0

for idx in "${TUI_MULTI_RESULT[@]}"; do
  case "$idx" in
    0)
      echo -e "${CYAN}$(msg docker_clean_running_containers)${NC}"
      if docker container prune -f; then
        success "$(msg docker_clean_done_containers)"
      else
        error "$(msg docker_clean_fail_containers)"
        fail_count=$((fail_count + 1))
        continue
      fi
      ;;
    1)
      echo -e "${CYAN}$(msg docker_clean_running_builder)${NC}"
      if docker builder prune -f; then
        success "$(msg docker_clean_done_builder)"
      else
        error "$(msg docker_clean_fail_builder)"
        fail_count=$((fail_count + 1))
        continue
      fi
      ;;
    2)
      echo -e "${CYAN}$(msg docker_clean_running_images)${NC}"
      if docker image prune -f; then
        success "$(msg docker_clean_done_images)"
      else
        error "$(msg docker_clean_fail_images)"
        fail_count=$((fail_count + 1))
        continue
      fi
      ;;
    3)
      echo -e "${CYAN}$(msg docker_clean_running_networks)${NC}"
      if docker network prune -f; then
        success "$(msg docker_clean_done_networks)"
      else
        error "$(msg docker_clean_fail_networks)"
        fail_count=$((fail_count + 1))
        continue
      fi
      ;;
    4)
      echo -e "${CYAN}$(msg docker_clean_running_volumes)${NC}"
      if docker volume prune -f; then
        success "$(msg docker_clean_done_volumes)"
      else
        error "$(msg docker_clean_fail_volumes)"
        fail_count=$((fail_count + 1))
        continue
      fi
      ;;
  esac
  success_count=$((success_count + 1))
  echo ""
done

# ============================================================
# Show Updated Disk Usage
# ============================================================

echo -e "${CYAN}$(msg docker_clean_disk_usage_after)${NC}"
echo ""
docker system df
echo ""

# ============================================================
# Summary
# ============================================================

if [[ "$fail_count" -eq 0 ]]; then
  echo -e "${GREEN}$(msg docker_clean_all_done "$success_count")${NC}"
else
  echo -e "${YELLOW}$(msg docker_clean_partial_done "$success_count" "$fail_count")${NC}"
  exit 1
fi
