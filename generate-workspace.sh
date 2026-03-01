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
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# ===== Global State =====
# TUI結果を受け渡すためのグローバル変数（サブシェル回避）
TUI_SINGLE_RESULT=""
TUI_MULTI_RESULT=()

# カーソル復元
cleanup() {
    printf '\033[?25h' >&2
}
trap cleanup EXIT

# ============================================================
# TUI Core: Key Reading
# ============================================================

# /dev/tty から1キー読み取り → 標準化された文字列を返す
# グローバル変数 KEY_PRESSED に結果を格納
KEY_PRESSED=""
read_key() {
    KEY_PRESSED=""
    local key=""
    IFS= read -rsn1 key </dev/tty 2>/dev/null || true

    if [[ "$key" == $'\033' ]]; then
        local seq1="" seq2=""
        IFS= read -rsn1 -t 0.1 seq1 </dev/tty 2>/dev/null || true
        IFS= read -rsn1 -t 0.1 seq2 </dev/tty 2>/dev/null || true
        case "${seq1}${seq2}" in
            "[A") KEY_PRESSED="UP" ;;
            "[B") KEY_PRESSED="DOWN" ;;
            *)    KEY_PRESSED="IGNORE" ;;
        esac
    elif [[ "$key" == "" ]]; then
        KEY_PRESSED="ENTER"
    elif [[ "$key" == " " ]]; then
        KEY_PRESSED="ENTER"  # スペースもEnterと同じ扱い
    elif [[ "$key" == "a" || "$key" == "A" ]]; then
        KEY_PRESSED="TOGGLE_ALL"
    elif [[ "$key" == "d" || "$key" == "D" ]]; then
        KEY_PRESSED="DONE"
    else
        KEY_PRESSED="IGNORE"
    fi
}

# ============================================================
# TUI Core: Single Select
# ============================================================

# 単一選択メニュー
# 引数: タイトル, 選択肢1, 選択肢2, ...
# 結果: TUI_SINGLE_RESULT にインデックスを格納
select_single() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local cursor=0

    printf '\033[?25l' >&2  # カーソル非表示

    while true; do
        # 描画
        printf '\033[K%b\n' "$title" >&2
        local i
        for i in "${!options[@]}"; do
            printf '\033[K' >&2
            if [[ "$i" -eq "$cursor" ]]; then
                printf '  %b❯ %s%b\n' "${CYAN}" "${options[$i]}" "${NC}" >&2
            else
                printf '    %s\n' "${options[$i]}" >&2
            fi
        done
        printf '\033[K  %b↑↓: 移動  Enter: 確定%b' "${DIM}" "${NC}" >&2

        # キー入力待ち
        read_key

        case "$KEY_PRESSED" in
            UP)
                [[ "$cursor" -gt 0 ]] && cursor=$((cursor - 1))
                ;;
            DOWN)
                [[ "$cursor" -lt $((count - 1)) ]] && cursor=$((cursor + 1))
                ;;
            ENTER)
                # 確定: メニューをクリアして結果表示
                printf '\033[%dA\r' $((count + 1)) >&2
                local j
                for ((j = 0; j < count + 2; j++)); do
                    printf '\033[K\n' >&2
                done
                printf '\033[%dA\r' $((count + 2)) >&2
                printf '\033[K%b → %b%s%b\n' "$title" "${GREEN}" "${options[$cursor]}" "${NC}" >&2

                printf '\033[?25h' >&2  # カーソル再表示
                TUI_SINGLE_RESULT="$cursor"
                return 0
                ;;
        esac

        # カーソルを描画開始位置に戻す
        printf '\033[%dA\r' $((count + 1)) >&2
    done
}

# ============================================================
# TUI Core: Multi Select
# ============================================================

# 複数選択メニュー
# 引数: タイトル, 初期選択CSV(例:"0,2"=インデックス), 選択肢1, 選択肢2, ...
# 結果: TUI_MULTI_RESULT 配列に選択されたインデックスを格納
select_multi() {
    local title="$1"
    local preselected_csv="$2"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local cursor=0

    # 選択状態配列
    local sel=()
    local i
    for ((i = 0; i < count; i++)); do
        sel+=("0")
    done

    # 初期選択を適用
    if [[ -n "$preselected_csv" ]]; then
        IFS=',' read -ra pre_idx <<< "$preselected_csv"
        local pi
        for pi in "${pre_idx[@]}"; do
            if [[ "$pi" =~ ^[0-9]+$ && "$pi" -lt "$count" ]]; then
                sel[$pi]="1"
            fi
        done
    fi

    printf '\033[?25l' >&2  # カーソル非表示

    while true; do
        # 描画
        printf '\033[K%b\n' "$title" >&2
        for i in "${!options[@]}"; do
            printf '\033[K' >&2
            local mark=" "
            [[ "${sel[$i]}" == "1" ]] && mark="✓"

            if [[ "$i" -eq "$cursor" ]]; then
                if [[ "${sel[$i]}" == "1" ]]; then
                    printf '  %b❯ [%b%s%b%b] %s%b\n' "${CYAN}" "${GREEN}" "$mark" "${NC}" "${CYAN}" "${options[$i]}" "${NC}" >&2
                else
                    printf '  %b❯ [%s] %s%b\n' "${CYAN}" "$mark" "${options[$i]}" "${NC}" >&2
                fi
            else
                if [[ "${sel[$i]}" == "1" ]]; then
                    printf '    [%b%s%b] %s\n' "${GREEN}" "$mark" "${NC}" "${options[$i]}" >&2
                else
                    printf '    [%s] %s\n' "$mark" "${options[$i]}" >&2
                fi
            fi
        done
        printf '\033[K  %b↑↓: 移動  Enter: 選択/解除  a: 全選択  d: 決定%b' "${DIM}" "${NC}" >&2

        # キー入力待ち
        read_key

        case "$KEY_PRESSED" in
            UP)
                [[ "$cursor" -gt 0 ]] && cursor=$((cursor - 1))
                ;;
            DOWN)
                [[ "$cursor" -lt $((count - 1)) ]] && cursor=$((cursor + 1))
                ;;
            ENTER)
                # カーソル位置をトグル
                if [[ "${sel[$cursor]}" == "1" ]]; then
                    sel[$cursor]="0"
                else
                    sel[$cursor]="1"
                fi
                ;;
            TOGGLE_ALL)
                local all_on=true
                local s
                for s in "${sel[@]}"; do
                    [[ "$s" == "0" ]] && all_on=false && break
                done
                local nv="1"
                [[ "$all_on" == true ]] && nv="0"
                for ((i = 0; i < count; i++)); do
                    sel[$i]="$nv"
                done
                ;;
            DONE)
                # 選択チェック
                local any=false
                for s in "${sel[@]}"; do
                    [[ "$s" == "1" ]] && any=true && break
                done
                if [[ "$any" == false ]]; then
                    # 警告表示
                    printf '\033[%dA\r' $((count + 1)) >&2
                    printf '\033[K%b\n' "$title" >&2
                    for i in "${!options[@]}"; do
                        printf '\033[K    [ ] %s\n' "${options[$i]}" >&2
                    done
                    printf '\033[K  %b⚠ 1つ以上選択してからdを押してください%b' "${YELLOW}" "${NC}" >&2
                    sleep 1
                    printf '\033[%dA\r' $((count + 1)) >&2
                    continue
                fi

                # 確定: メニューをクリアして結果表示
                printf '\033[%dA\r' $((count + 1)) >&2
                local j
                for ((j = 0; j < count + 2; j++)); do
                    printf '\033[K\n' >&2
                done
                printf '\033[%dA\r' $((count + 2)) >&2

                printf '\033[K%b →' "$title" >&2
                local first=true
                for i in "${!options[@]}"; do
                    if [[ "${sel[$i]}" == "1" ]]; then
                        if [[ "$first" == true ]]; then
                            printf ' %b%s%b' "${GREEN}" "${options[$i]}" "${NC}" >&2
                            first=false
                        else
                            printf ', %b%s%b' "${GREEN}" "${options[$i]}" "${NC}" >&2
                        fi
                    fi
                done
                printf '\n' >&2

                printf '\033[?25h' >&2  # カーソル再表示

                # 結果配列を構築
                TUI_MULTI_RESULT=()
                for i in "${!options[@]}"; do
                    [[ "${sel[$i]}" == "1" ]] && TUI_MULTI_RESULT+=("$i")
                done
                return 0
                ;;
        esac

        # カーソルを描画開始位置に戻す
        printf '\033[%dA\r' $((count + 1)) >&2
    done
}

# ============================================================
# Business Logic Functions
# ============================================================

# 親ディレクトリ内のフォルダ一覧を取得（隠しフォルダ除く）
get_available_dirs() {
    find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf '%f\n' | sort
}

# 既存の .code-workspace ファイル一覧を取得（workspaces/ 内）
get_workspace_files() {
    find "$WORKSPACES_DIR" -maxdepth 1 -name "*.code-workspace" -printf '%f\n' 2>/dev/null | sort
}

# ワークスペースファイルから現在のフォルダ一覧を取得
get_current_folders() {
    local file="$1"
    grep '"name":' "$file" | sed 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/'
}

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
    done < <(get_available_dirs)

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
    select_multi "${BOLD}ワークスペースに含めるフォルダを選択:${NC}" "$preselected" "${dirs[@]}"

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

# ワークスペースファイル生成
generate_workspace_file() {
    local output_file="$1"
    shift
    local folders=("$@")

    {
        printf '{\n'
        printf '\t"folders": [\n'

        local i=0
        local count=${#folders[@]}
        local folder
        for folder in "${folders[@]}"; do
            i=$((i + 1))
            local comma=""
            if [[ "$i" -lt "$count" ]]; then
                comma=","
            fi
            printf '\t\t{\n'
            printf '\t\t\t"name": "%s",\n' "$folder"
            printf '\t\t\t"path": "../../%s"\n' "$folder"
            printf '\t\t}%s\n' "$comma"
        done

        printf '\t],\n'
        printf '\t"settings": {\n'
        printf '\t\t// Add global settings here\n'
        printf '\t\t"files.autoSave": "afterDelay",\n'
        printf '\t\t"editor.formatOnSave": true\n'
        printf '\t}\n'
        printf '}\n'
    } > "$output_file"

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

    generate_workspace_file "$output_path" "${selected_folders[@]}"
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
    done < <(get_workspace_files)

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
                generate_workspace_file "$output_path" "${SELECTED_FOLDERS[@]}"
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
