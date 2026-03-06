#!/bin/bash

# ============================================================
# generate-workspace.sh - .code-workspace ファイル ジェネレーター
# ============================================================
# ワークスペースに含めるフォルダを対話的に選択し、
# workspaces/ 内に .code-workspace ファイルを新規作成・更新します。
#
# 操作方法（単一選択）:
#   ↑/↓    カーソル移動
#   Enter  確定
#
# 操作方法（複数選択）:
#   ↑/↓    カーソル移動
#   Enter  選択/解除
#   a      全選択/全解除
#   d      決定
#
# 使い方: ./generate-workspace.sh
# ============================================================

# set -e は算術式 exit code やサブシェルの問題を起こすため使用しない
set -uo pipefail

# ===== Script Location =====
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACES_DIR="$SCRIPT_DIR/workspaces"

# ===== Colors =====
# shellcheck source=lib/colors.sh
source "$SCRIPT_DIR/lib/colors.sh"

# ===== TUI Components =====
# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"

# ===== Business Logic =====
# shellcheck source=lib/workspace.sh
source "$SCRIPT_DIR/lib/workspace.sh"

# カーソル復元
cleanup() {
  tui_cleanup
}
trap cleanup EXIT

# ============================================================
# Business Logic Functions (TUI-dependent)
# ============================================================
# Pure business logic is in lib/workspace.sh
# Below are TUI-dependent orchestration functions

# フォルダの対話的選択
# 引数: $1 = 更新対象のワークスペースファイルパス（任意）
# 結果: SELECTED_FOLDERS 配列に選択されたフォルダ名を格納
SELECTED_FOLDERS=()
interactive_select_folders() {
  local current_file="${1:-}"

  # 利用可能なフォルダ一覧
  local dirs=()
  while IFS= read -r dir; do
    [[ -n "$dir" ]] && dirs+=("$dir")
  done < <(get_available_dirs "$PARENT_DIR")

  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR:${NC} 親ディレクトリにフォルダが見つかりません" >&2
    exit 1
  fi

  # 更新時: 現在のフォルダ構成から初期選択を構築
  local preselected=""
  if [[ -n "$current_file" && -f "$current_file" ]]; then
    local current_folders=()
    while IFS= read -r folder; do
      [[ -n "$folder" ]] && current_folders+=("$folder")
    done < <(get_current_folders "$current_file")

    local indices=()
    local i cf
    for i in "${!dirs[@]}"; do
      for cf in "${current_folders[@]}"; do
        if [[ "${dirs[$i]}" == "$cf" ]]; then
          indices+=("$i")
          break
        fi
      done
    done
    if [[ ${#indices[@]} -gt 0 ]]; then
      local IFS=','
      preselected="${indices[*]}"
    fi
  fi

  # TUI multi-select 実行（結果は TUI_MULTI_RESULT に格納される）
  select_multi "${BOLD}ワークスペースに含めるフォルダを選択:${NC}" "$preselected" "${dirs[@]}" || {
    echo "キャンセルしました" >&2
    exit 0
  }

  if [[ ${#TUI_MULTI_RESULT[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR:${NC} フォルダが選択されていません" >&2
    exit 1
  fi

  # 選択されたフォルダ名を配列に格納
  SELECTED_FOLDERS=()
  local idx
  for idx in "${TUI_MULTI_RESULT[@]}"; do
    SELECTED_FOLDERS+=("${dirs[$idx]}")
  done
}

# ワークスペースファイル生成（TUI出力付きラッパー）
_generate_workspace_file_with_output() {
  local output_file="$1"
  shift
  local folders=("$@")
  local settings_file="$SCRIPT_DIR/config/workspace-settings.json"
  if [[ ! -f "$settings_file" ]]; then
    settings_file="$SCRIPT_DIR/config/workspace-settings.json.example"
  fi

  generate_workspace_file "$output_file" "$settings_file" "${folders[@]}"

  echo "" >&2
  echo -e "${GREEN}✅ ワークスペースファイルを生成しました:${NC}" >&2
  echo -e "   ${BOLD}workspaces/$(basename "$output_file")${NC}" >&2
  echo "" >&2
  echo "含まれるプロジェクト:" >&2
  for folder in "${folders[@]}"; do
    echo "  - $folder" >&2
  done
}

# ファイル名入力（空入力時はループ）
create_new_workspace() {
  local selected_folders=("$@")
  local filename=""

  while true; do
    echo "" >&2
    read -rp "ファイル名を入力してください（.code-workspace は自動付与）: " filename
    filename=$(echo "$filename" | xargs)
    if [[ -n "$filename" ]]; then
      break
    fi
    echo -e "${YELLOW}⚠ ファイル名を入力してください${NC}" >&2
  done

  filename="${filename%.code-workspace}"
  local output_path="$WORKSPACES_DIR/${filename}.code-workspace"

  if [[ -f "$output_path" ]]; then
    echo -e "${YELLOW}⚠ ${filename}.code-workspace は既に存在します。上書きしますか？${NC}" >&2
    read -rp "[y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "キャンセルしました" >&2
      exit 0
    fi
  fi

  _generate_workspace_file_with_output "$output_path" "${selected_folders[@]}"
}

# ============================================================
# Main
# ============================================================

main() {
  # workspaces ディレクトリの確認・作成
  if [[ ! -d "$WORKSPACES_DIR" ]]; then
    mkdir -p "$WORKSPACES_DIR"
  fi

  echo "" >&2
  echo -e "${BOLD}========================================" >&2
  echo " .code-workspace ファイル ジェネレーター" >&2
  echo -e "========================================${NC}" >&2
  echo "" >&2
  echo -e "スキャン対象:   ${BOLD}${PARENT_DIR}${NC}" >&2
  echo -e "出力先:         ${BOLD}workspaces/${NC}" >&2
  echo "" >&2

  # 既存の .code-workspace ファイルを検索
  local workspace_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && workspace_files+=("$file")
  done < <(get_workspace_files "$WORKSPACES_DIR")

  if [[ ${#workspace_files[@]} -gt 0 ]]; then
    # ===== 既存ファイルあり =====
    echo -e "${CYAN}既存のワークスペースファイル:${NC}" >&2
    local f
    for f in "${workspace_files[@]}"; do
      echo "  - $f" >&2
    done
    echo "" >&2

    # 更新 / 新規作成 を選択
    select_single "${BOLD}操作を選択してください:${NC}" "既存ファイルを更新" "新規作成"
    local action_idx="$TUI_SINGLE_RESULT"

    case "$action_idx" in
      0)
        # === 既存ファイルを更新 ===
        echo "" >&2
        select_single "${BOLD}更新するファイルを選択してください:${NC}" "${workspace_files[@]}"
        local file_idx="$TUI_SINGLE_RESULT"

        local target_file="${workspace_files[$file_idx]}"
        local output_path="$WORKSPACES_DIR/$target_file"

        echo "" >&2
        interactive_select_folders "$output_path"
        _generate_workspace_file_with_output "$output_path" "${SELECTED_FOLDERS[@]}"
        ;;
      1)
        # === 新規作成 ===
        echo "" >&2
        interactive_select_folders
        create_new_workspace "${SELECTED_FOLDERS[@]}"
        ;;
    esac
  else
    # ===== 既存ファイルなし → 新規作成 =====
    echo "ワークスペースファイルが見つかりません。新規作成します。" >&2
    echo "" >&2

    interactive_select_folders
    create_new_workspace "${SELECTED_FOLDERS[@]}"
  fi
}

main
