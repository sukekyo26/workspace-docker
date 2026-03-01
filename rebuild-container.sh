#!/bin/bash

# ============================================================
# rebuild-container.sh - キャッシュなし Dev Container リビルド
# ============================================================
# ホストOSから実行し、Docker イメージをキャッシュなしで再ビルドした上で
# Dev Container を再作成・起動します。
#
# ※ コンテナ内からは実行できません
#
# 使い方: ./rebuild-container.sh
#
# 前提条件:
#   - Docker がインストール・起動済みであること
#   - curl がインストール済みであること（devcontainer CLI 自動インストール用）
# ============================================================

set -euo pipefail

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ===== Resolve Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR"
# ===== Load Shared Libraries =====
source "$SCRIPT_DIR/lib/devcontainer.sh"
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
echo " キャッシュなしリビルドスクリプト"
echo -e "========================================${NC}"
echo ""
echo -e "ワークスペース: ${BOLD}${WORKSPACE_DIR}${NC}"

# ============================================================
# Prerequisites Check (via lib/devcontainer.sh)
# ============================================================

check_all_prerequisites "$WORKSPACE_DIR"

# ============================================================
# Show Current Image Info
# ============================================================

echo ""

SERVICE_NAME=$(grep -oP '^CONTAINER_SERVICE_NAME=\K.*' "$WORKSPACE_DIR/.env" 2>/dev/null || echo "dev")
WORKSPACE_NAME=$(basename "$WORKSPACE_DIR")
IMAGE_NAME="${WORKSPACE_NAME}-${SERVICE_NAME}"

if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    CREATED_DATE=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' 2>/dev/null || true)
    if [[ -n "$CREATED_DATE" ]]; then
        CREATED_EPOCH=$(date -d "$CREATED_DATE" +%s 2>/dev/null || echo "0")
        CURRENT_EPOCH=$(date +%s)
        DAYS_OLD=$(( (CURRENT_EPOCH - CREATED_EPOCH) / 86400 ))
        FORMATTED_DATE=$(date -d "$CREATED_DATE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$CREATED_DATE")

        echo -e "現在のイメージ: ${BOLD}${IMAGE_NAME}${NC}"
        echo -e "作成日:         ${BOLD}${FORMATTED_DATE}${NC} (${DAYS_OLD}日前)"
    fi
else
    echo -e "イメージ ${BOLD}${IMAGE_NAME}${NC} が見つかりません（初回ビルド）"
fi

# ============================================================
# Confirmation
# ============================================================

echo ""
echo -e "${YELLOW}⚠ 注意事項:${NC}"
echo "  ・Docker イメージをキャッシュなしでリビルドします"
echo "  ・既存コンテナを削除して再作成します"
echo "  ・リビルドには数分かかる場合があります"
echo ""
read -rp "リビルドを実行しますか？ [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "キャンセルしました"
    exit 0
fi

# ============================================================
# Rebuild & Start
# ============================================================

echo ""
echo -e "${CYAN}🔨 キャッシュなしでリビルド & 起動中...${NC}"
echo -e "${YELLOW}   これには数分かかる場合があります${NC}"
echo ""

run_devcontainer up \
    --workspace-folder "$WORKSPACE_DIR" \
    --build-no-cache \
    --remove-existing-container

# ============================================================
# Done
# ============================================================

echo ""
echo -e "${GREEN}✅ リビルド & 起動が完了しました${NC}"

# 新しいイメージの情報を表示
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    NEW_DATE=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' 2>/dev/null || true)
    if [[ -n "$NEW_DATE" ]]; then
        NEW_FORMATTED=$(date -d "$NEW_DATE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$NEW_DATE")
        echo -e "新しいイメージ作成日: ${BOLD}${NEW_FORMATTED}${NC}"
    fi
fi

echo ""
echo -e "${CYAN}📌 VS Code で Ctrl+Shift+P →${NC}"
echo -e "${CYAN}   '開発コンテナー: コンテナで再度開く' を実行してください${NC}"
echo ""
