#!/bin/bash
# ============================================================
# lib/devcontainer.sh - devcontainer CLI & Docker prerequisite checks
# ============================================================
# rebuild-container.sh から source して使う共通ライブラリ。
#
# 提供する関数:
#   check_docker            Docker のインストール・起動確認
#   check_devcontainer_cli  devcontainer CLI の確認・自動インストール
#   check_devcontainer_json devcontainer.json の存在確認
#   check_env_file          .env の存在確認
#   check_all_prerequisites 上記すべてを一括実行
#   is_wsl                  WSL 環境かどうか判定
#   run_devcontainer        WSL 環境を考慮した devcontainer CLI ラッパー
# ============================================================

# Load shared color constants
_DC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=colors.sh
source "$_DC_LIB_DIR/colors.sh"

# ============================================================
# check_docker
# ============================================================
# Docker がインストールされ、デーモンが起動していることを確認する。
# 失敗した場合は exit 1 で終了する。
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "  ${RED}✗${NC} Docker がインストールされていません"
        echo "    → https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info &> /dev/null 2>&1; then
        echo -e "  ${RED}✗${NC} Docker デーモンが起動していません"
        echo "    → Docker Desktop を起動するか、sudo systemctl start docker を実行してください"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Docker"
}

# ============================================================
# check_devcontainer_cli
# ============================================================
# devcontainer CLI の存在を確認し、なければ curl で自動インストールする。
# インストール URL:
#   https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh
check_devcontainer_cli() {
    if ! command -v devcontainer &> /dev/null; then
        echo -e "  ${YELLOW}✗${NC} devcontainer CLI が見つかりません"

        if command -v curl &> /dev/null; then
            echo -e "    ${CYAN}→ インストール中...${NC}"
            local install_script
            install_script=$(mktemp)
            curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh -o "$install_script"
            sh "$install_script"
            rm -f "$install_script"
            echo -e "  ${GREEN}✓${NC} devcontainer CLI をインストールしました"
        else
            echo -e "  ${RED}✗${NC} curl が見つかりません"
            echo "    devcontainer CLI をインストールするには curl が必要です:"
            echo "      curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh | sh"
            exit 1
        fi
    else
        echo -e "  ${GREEN}✓${NC} devcontainer CLI"
    fi
}

# ============================================================
# check_devcontainer_json <workspace_dir>
# ============================================================
check_devcontainer_json() {
    local workspace_dir="$1"
    if [[ ! -f "$workspace_dir/.devcontainer/devcontainer.json" ]]; then
        echo -e "  ${RED}✗${NC} .devcontainer/devcontainer.json が見つかりません"
        echo "    → 先に setup-docker.sh を実行してください"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} devcontainer.json"
}

# ============================================================
# check_env_file <workspace_dir>
# ============================================================
check_env_file() {
    local workspace_dir="$1"
    if [[ ! -f "$workspace_dir/.env" ]]; then
        echo -e "  ${RED}✗${NC} .env が見つかりません"
        echo "    → 先に setup-docker.sh を実行してください"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} .env"
}

# ============================================================
# check_all_prerequisites <workspace_dir>
# ============================================================
# Docker, devcontainer CLI, devcontainer.json, .env をまとめて確認する。
check_all_prerequisites() {
    local workspace_dir="$1"

    echo ""
    echo -e "${CYAN}前提条件を確認中...${NC}"

    check_docker
    check_devcontainer_cli
    check_devcontainer_json "$workspace_dir"
    check_env_file "$workspace_dir"
}

# ============================================================
# is_wsl
# ============================================================
# WSL 環境 (WSL1/WSL2) で実行されているかどうかを判定する。
is_wsl() {
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        return 0
    fi
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        return 0
    fi
    return 1
}

# ============================================================
# run_devcontainer
# ============================================================
# devcontainer CLI のラッパー関数。
#
# WSL 環境では devcontainer CLI が /proc/version から WSL を検出し、
# docker コマンドの実行を Windows 側にブリッジしてしまう。
# Windows に Docker Desktop がインストールされていない場合、
# ENOENT (docker not found on Windows PATH) でコンテナ起動に失敗する。
#
# この関数は WSL 環境で以下を行うことで問題を回避する:
#   1. DOCKER_HOST を WSL 内の Docker ソケットに export
#   2. --docker-path で WSL 内の docker バイナリを明示指定
#
# これにより CLI は Windows 側に Docker を探しに行かず、
# WSL 内の Docker を直接使用する。
#
# EC2 等の通常 Linux 環境では WSL が検出されないためそのまま実行する。
#
# 使い方:
#   run_devcontainer up --workspace-folder "$DIR"
#   run_devcontainer up --workspace-folder "$DIR" --build-no-cache
run_devcontainer() {
    if is_wsl; then
        local docker_path
        docker_path=$(command -v docker 2>/dev/null || true)

        if [[ -z "$docker_path" ]]; then
            echo -e "  ${RED}✗${NC} WSL 内で docker が見つかりません"
            exit 1
        fi

        export DOCKER_HOST="unix:///var/run/docker.sock"
        devcontainer "$@" --docker-path "$docker_path"
    else
        devcontainer "$@"
    fi
}
