#!/bin/bash

# ============================================================
# clean-volumes.sh - Docker ボリューム全削除スクリプト
# ============================================================
# ホストOSから実行し、このプロジェクトに関連する Docker named volume を
# すべて削除します。
#
# ※ コンテナ内からは実行できません
#
# 使い方: ./clean-volumes.sh
#
# 前提条件:
#   - Docker がインストール・起動済みであること
# ============================================================

set -euo pipefail

# ===== Resolve Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR"

# ===== Load Shared Libraries =====
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# ============================================================
# Container Environment Check
# ============================================================

if [[ -f /.dockerenv ]] || grep -qsE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
  echo -e "${RED}ERROR:${NC} このスクリプトはコンテナ内からは実行できません"
  echo "  ホストOSから実行してください"
  exit 1
fi

echo ""
echo -e "${BOLD}========================================"
echo " Docker ボリューム削除スクリプト"
echo -e "========================================${NC}"
echo ""
echo -e "ワークスペース: ${BOLD}${WORKSPACE_DIR}${NC}"

# ============================================================
# Prerequisites Check
# ============================================================

if ! command -v docker &>/dev/null; then
  echo -e "${RED}ERROR:${NC} docker コマンドが見つかりません"
  exit 1
fi

# ============================================================
# Detect Project Volumes
# ============================================================

SERVICE_NAME=$(read_env_var "CONTAINER_SERVICE_NAME" "$WORKSPACE_DIR/.env" || echo "dev")
PROJECT_NAME=$(read_env_var "COMPOSE_PROJECT_NAME" "$WORKSPACE_DIR/.env" || basename "$WORKSPACE_DIR")
VOLUME_PREFIX="${PROJECT_NAME}_${SERVICE_NAME}_"

echo ""
echo -e "プロジェクト名: ${BOLD}${PROJECT_NAME}${NC}"
echo -e "サービス名:     ${BOLD}${SERVICE_NAME}${NC}"
echo -e "ボリューム接頭辞: ${BOLD}${VOLUME_PREFIX}${NC}"
echo ""

# Find volumes matching the project prefix
mapfile -t volumes < <(docker volume ls --format '{{.Name}}' | grep "^${VOLUME_PREFIX}" 2>/dev/null || true)

if [[ ${#volumes[@]} -eq 0 ]]; then
  echo -e "${YELLOW}削除対象のボリュームが見つかりません${NC}"
  echo "  プレフィックス: ${VOLUME_PREFIX}"
  exit 0
fi

echo -e "${CYAN}削除対象のボリューム (${#volumes[@]}件):${NC}"
for vol in "${volumes[@]}"; do
  echo "  - $vol"
done

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}⚠ 注意事項:${NC}"
echo "  ・上記のボリュームをすべて削除します"
echo "  ・ボリューム内のデータは復元できません"
echo "  ・コンテナが起動中の場合は先に停止してください"
echo ""
read -rp "削除を実行しますか？ [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "キャンセルしました"
  exit 0
fi

# ============================================================
# Stop Containers if Running
# ============================================================

if docker compose -f "$WORKSPACE_DIR/docker-compose.yml" ps -q 2>/dev/null | grep -q .; then
  echo ""
  echo -e "${CYAN}コンテナを停止中...${NC}"
  docker compose -f "$WORKSPACE_DIR/docker-compose.yml" down 2>/dev/null || true
fi

# ============================================================
# Delete Volumes
# ============================================================

echo ""
echo -e "${CYAN}ボリュームを削除中...${NC}"

failed=0
for vol in "${volumes[@]}"; do
  if docker volume rm "$vol" 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $vol"
  else
    echo -e "  ${RED}❌${NC} $vol (削除失敗 — 使用中の可能性があります)"
    failed=$((failed + 1))
  fi
done

# ============================================================
# Done
# ============================================================

echo ""
if [[ "$failed" -eq 0 ]]; then
  echo -e "${GREEN}✅ ${#volumes[@]}件のボリュームをすべて削除しました${NC}"
else
  echo -e "${YELLOW}⚠ $((${#volumes[@]} - failed))件削除、${failed}件失敗${NC}"
  exit 1
fi
