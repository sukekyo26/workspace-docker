#!/bin/bash
# ============================================================
# lib/tui.sh - Terminal UI components
# ============================================================
# Reusable TUI components for interactive shell scripts.
# Provides single-select and multi-select menu widgets.
#
# Functions:
#   read_key       Read a single key from /dev/tty
#   select_single  Single-select menu
#   select_multi   Multi-select menu
#
# Global State:
#   KEY_PRESSED         Last key read by read_key
#   TUI_SINGLE_RESULT   Selected index from select_single
#   TUI_MULTI_RESULT    Selected indices from select_multi
# ============================================================
# Sourced by other scripts; variables are used externally.
# shellcheck disable=SC2034
set -uo pipefail

# Load shared color constants
_TUI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=colors.sh
source "$_TUI_LIB_DIR/colors.sh"

# ===== Global State =====
TUI_SINGLE_RESULT=""
TUI_MULTI_RESULT=()

# カーソル復元
tui_cleanup() {
  printf '\033[?25h' >&2
}

# ============================================================
# Key Reading
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
  elif [[ "$key" == "q" || "$key" == "Q" ]]; then
    KEY_PRESSED="CANCEL"
  else
    KEY_PRESSED="IGNORE"
  fi
}

# ============================================================
# Single Select
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
# Multi Select
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
        sel[pi]="1"
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
    printf '\033[K  %b↑↓: 移動  Enter: 選択/解除  a: 全選択  d: 決定  q: キャンセル%b' "${DIM}" "${NC}" >&2

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
        if [[ "${sel[cursor]}" == "1" ]]; then
          sel[cursor]="0"
        else
          sel[cursor]="1"
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
          sel[i]="$nv"
        done
        ;;
      CANCEL)
        # キャンセル: メニューをクリアしてキャンセルメッセージ表示
        printf '\033[%dA\r' $((count + 1)) >&2
        local j
        for ((j = 0; j < count + 2; j++)); do
          printf '\033[K\n' >&2
        done
        printf '\033[%dA\r' $((count + 2)) >&2
        printf '\033[K%b → %bキャンセル%b\n' "$title" "${YELLOW}" "${NC}" >&2
        printf '\033[?25h' >&2
        TUI_MULTI_RESULT=()
        return 1
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
