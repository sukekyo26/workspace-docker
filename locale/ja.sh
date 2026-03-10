#!/bin/bash
# locale/ja.sh — 日本語メッセージカタログ
# shellcheck disable=SC2034,SC2154

# ============================================================
# validators.sh
# ============================================================
_MSG[err_service_name_empty]="コンテナサービス名が空です"
_MSG[err_service_name_invalid]="コンテナサービス名には英数字、ハイフン、アンダースコアのみ使用できます"
_MSG[err_service_name_too_long]="コンテナサービス名は64文字以下にしてください"
_MSG[err_username_empty]="ユーザー名が空です"
_MSG[err_username_blocked]="ユーザー名 '%s' はシステム予約アカウントのため使用できません"
_MSG[err_username_invalid]="ユーザー名は小文字またはアンダースコアで始まり、小文字・数字・アンダースコア・ハイフンのみ使用できます"
_MSG[err_username_too_long]="ユーザー名は32文字以下にしてください"
_MSG[err_boolean_invalid]="値は 'true' または 'false' でなければなりません"
_MSG[err_file_not_found]="%s が見つかりません: %s"
_MSG[err_dir_not_found]="%s が見つかりません: %s"
_MSG[warn_apt_duplicate]="[apt] packages に '%s' が含まれていますが、apt-base-packages.conf に既に定義されています"
_MSG[warn_apt_remove_duplicates]="冗長なインストールを避けるため workspace.toml の [apt] packages から重複を削除してください"

# ============================================================
# devcontainer.sh
# ============================================================
_MSG[dc_docker_not_installed]="Docker がインストールされていません"
_MSG[dc_docker_install_url]="→ https://docs.docker.com/get-docker/"
_MSG[dc_docker_not_running]="Docker デーモンが起動していません"
_MSG[dc_docker_start_hint]="→ Docker Desktop を起動するか、次を実行: sudo systemctl start docker"
_MSG[dc_cli_not_found]="devcontainer CLI が見つかりません"
_MSG[dc_install_prompt]="devcontainer CLI を自動インストールしますか？"
_MSG[dc_install_declined]="devcontainer CLI のインストールがキャンセルされました"
_MSG[dc_installing]="→ インストール中..."
_MSG[dc_install_failed]="インストールスクリプトのダウンロードに失敗しました"
_MSG[dc_install_not_in_path]="devcontainer CLI はインストールされましたが PATH に見つかりません"
_MSG[dc_path_added]="%s を現在のセッションの PATH に追加しました"
_MSG[dc_path_persist_hint]="永続化するにはシェルプロファイルに追加してください: export PATH=\"%s:\$PATH\""
_MSG[dc_curl_not_found]="curl が見つかりません"
_MSG[dc_curl_install_hint]="devcontainer CLI のインストールには curl が必要です:"
_MSG[dc_json_not_found]=".devcontainer/devcontainer.json が見つかりません"
_MSG[dc_run_setup_first]="→ 先に setup-docker.sh を実行してください"
_MSG[dc_env_not_found]=".env が見つかりません"
_MSG[dc_checking_prereqs]="前提条件を確認中..."
_MSG[dc_docker_not_found_wsl]="WSL 内に docker が見つかりません"

# ============================================================
# plugins.sh
# ============================================================
_MSG[err_uv_not_found]="uv が必要ですが見つかりません。"
_MSG[err_uv_install_hint]="  uv のインストール: curl -LsSf https://astral.sh/uv/install.sh | sh"
_MSG[err_toml_check_failed]="TOML パーサーのチェックに失敗しました。"
_MSG[err_toml_run_sync]="  実行: uv sync --no-dev（プロジェクトルートで）"
_MSG[err_workspace_toml_not_found]="workspace.toml が見つかりません: %s"
_MSG[err_plugins_dir_not_found]="プラグインディレクトリが見つかりません: %s"
_MSG[err_plugin_not_found]="プラグインが見つかりません: %s"

# ============================================================
# generators.sh
# ============================================================
_MSG[err_generate_failed]="%s の生成に失敗しました (%s)"

# ============================================================
# utils.sh
# ============================================================
_MSG[err_invalid_var_name]="TOML 出力に無効な変数名があります: %s"
_MSG[err_unexpected_var]="TOML 出力に予期しない変数があります: %s"
_MSG[err_unknown_type_prefix]="TOML 出力に不明な型プレフィックスがあります: %s"

# ============================================================
# tui.sh
# ============================================================
_MSG[tui_move_confirm]="↑↓: 移動  Enter: 確定"
_MSG[tui_move_toggle]="↑↓: 移動  Enter: 切替  a: 全選択  d: 決定  q: 取消"
_MSG[tui_select_at_least_one]="⚠ d を押す前に1つ以上選択してください"

# ============================================================
# setup-docker.sh
# ============================================================
_MSG[setup_unknown_arg]="不明な引数: %s"
_MSG[setup_header_regenerate]="workspace.toml から再生成"
_MSG[setup_service_info]="サービス: %s"
_MSG[setup_username_info]="ユーザー名: %s"
_MSG[setup_plugins_info]="プラグイン: %s"
_MSG[setup_header_generate]="Ubuntu on Docker 用 Dockerfile 生成"
_MSG[setup_service_default]="サービス名: %s (デフォルト)"
_MSG[setup_username_current]="ユーザー名: %s (現在のユーザー)"
_MSG[setup_prompt_service_name]="コンテナサービス名を入力: "
_MSG[setup_prompt_username]="Ubuntu on Docker ユーザー名を入力: "
_MSG[setup_header_software]="ソフトウェアインストール選択"
_MSG[setup_plugin_enabled]="  %s: 有効 (デフォルト)"
_MSG[setup_plugin_skipped]="  %s: スキップ"
_MSG[setup_select_plugins]="インストールするプラグインを選択:"
_MSG[setup_port_default]="フォワードポート: %s (デフォルト)"
_MSG[setup_header_port]="ポート設定"
_MSG[setup_prompt_port]="フォワードポート [3000]: "
_MSG[setup_invalid_port]="有効なポート番号を入力してください (1-65535)"
_MSG[setup_gen_workspace_toml]="workspace.toml を生成中..."
_MSG[setup_gen_compose]="docker-compose.yml を生成中..."
_MSG[setup_gen_dockerfile]="Dockerfile を生成中..."
_MSG[setup_header_certs]="カスタム CA 証明書を検出"
_MSG[setup_certs_will_install]="以下の証明書が certs/ からインストールされます:"
_MSG[setup_gen_devcontainer_json]=".devcontainer/devcontainer.json を生成中..."
_MSG[setup_gen_devcontainer_compose]=".devcontainer/docker-compose.yml を生成中..."
_MSG[setup_gen_env]=".env を生成中..."
_MSG[setup_created_bashrc]="config/.bashrc_custom をサンプルから作成しました"
_MSG[setup_docker_gid_failed]="Docker GID の検出に失敗しました"
_MSG[setup_docker_gid_hint]="試行: /var/run/docker.sock, rootless ソケット, docker グループ\nDocker がインストールされ起動していることを確認してください"
_MSG[setup_detected_docker_gid]="Docker GID を検出: %s"
_MSG[setup_complete]="=== セットアップ完了 ==="
_MSG[setup_result_service]="コンテナサービス名: %s"
_MSG[setup_result_username]="ユーザー名: %s"
_MSG[setup_result_uid_gid]="UID/GID: %s/%s (自動検出)"
_MSG[setup_result_docker_gid]="Docker GID: %s (自動検出)"
_MSG[setup_result_plugins]="有効なプラグイン:"
_MSG[setup_result_plugin_item]="  - %s: はい"
_MSG[setup_result_certs]="  - カスタム CA 証明書: はい (certs/ から)"
_MSG[setup_result_port]="ポートフォワーディング: %s"
_MSG[setup_result_files]="生成されたファイル:"
_MSG[setup_build_hint]="Docker イメージは以下のコマンドでビルドできます:"
_MSG[setup_start_hint]="コンテナの起動:"
_MSG[setup_access_hint]="コンテナへのアクセス:"
_MSG[setup_stop_hint]="コンテナの停止:"
_MSG[setup_reconfig_hint]="再設定:"

# ============================================================
# generate-workspace.sh
# ============================================================
_MSG[gen_ws_no_folders]="親ディレクトリにフォルダが見つかりません"
_MSG[gen_ws_cancelled]="キャンセルしました"
_MSG[gen_ws_no_selection]="フォルダが選択されていません"
_MSG[gen_ws_file_generated]="✅ ワークスペースファイルを生成しました:"
_MSG[gen_ws_included_projects]="含まれるプロジェクト:"
_MSG[gen_ws_prompt_filename]="ファイル名を入力（.code-workspace は自動付与）: "
_MSG[gen_ws_empty_filename]="⚠ ファイル名を入力してください"
_MSG[gen_ws_overwrite]="⚠ %s.code-workspace は既に存在します。上書きしますか？"
_MSG[gen_ws_confirm_yn]="[y/N]: "
_MSG[gen_ws_header]=".code-workspace ファイルジェネレーター"
_MSG[gen_ws_scan_target]="スキャン対象:"
_MSG[gen_ws_output_dir]="出力先:"
_MSG[gen_ws_existing_files]="既存のワークスペースファイル:"
_MSG[gen_ws_select_action]="操作を選択:"
_MSG[gen_ws_update_existing]="既存ファイルを更新"
_MSG[gen_ws_create_new]="新規作成"
_MSG[gen_ws_select_file]="更新するファイルを選択:"
_MSG[gen_ws_no_files]="ワークスペースファイルが見つかりません。新規作成します。"
_MSG[gen_ws_select_folders]="ワークスペースに含めるフォルダを選択:"

# ============================================================
# rebuild-container.sh
# ============================================================
_MSG[rebuild_inside_container]="このスクリプトはコンテナ内から実行できません"
_MSG[rebuild_header]="キャッシュなしリビルドスクリプト"
_MSG[rebuild_workspace]="ワークスペース:"
_MSG[rebuild_current_image]="現在のイメージ: %s"
_MSG[rebuild_created]="作成日時:       %s (%s 日前)"
_MSG[rebuild_image_not_found]="イメージ %s が見つかりません（初回ビルド）"
_MSG[rebuild_notice]="⚠ 注意:"
_MSG[rebuild_notice_1]="  - Docker イメージがキャッシュなしでリビルドされます"
_MSG[rebuild_notice_2]="  - 既存のコンテナは削除され再作成されます"
_MSG[rebuild_notice_3]="  - リビルドには数分かかる場合があります"
_MSG[rebuild_confirm]="リビルドを実行しますか？ [y/N]: "
_MSG[rebuild_cancelled]="キャンセルしました"
_MSG[rebuild_starting]="🔨 キャッシュなしでリビルド＆起動中..."
_MSG[rebuild_please_wait]="   数分かかる場合があります"
_MSG[rebuild_complete]="✅ リビルド＆起動完了"
_MSG[rebuild_new_image]="新しいイメージを作成: %s"
_MSG[rebuild_vscode_1]="📌 VS Code で Ctrl+Shift+P を押して →"
_MSG[rebuild_vscode_2]="   'Dev Containers: Reopen in Container'"

# ============================================================
# clean-volumes.sh
# ============================================================
_MSG[clean_inside_container]="このスクリプトはコンテナ内から実行できません"
_MSG[clean_header]="Docker ボリュームクリーンアップスクリプト"
_MSG[clean_workspace]="ワークスペース:"
_MSG[clean_docker_not_found]="docker コマンドが見つかりません"
_MSG[clean_docker_not_running]="Docker デーモンが起動していません"
_MSG[clean_project_name]="プロジェクト名:"
_MSG[clean_service_name]="サービス名:"
_MSG[clean_volume_prefix]="ボリュームプレフィックス:"
_MSG[clean_no_volumes]="削除するボリュームがありません"
_MSG[clean_prefix_info]="  プレフィックス: %s"
_MSG[clean_volumes_header]="削除するボリューム (%s):"
_MSG[clean_notice]="⚠ 注意:"
_MSG[clean_notice_1]="  - 上記のボリュームがすべて削除されます"
_MSG[clean_notice_2]="  - ボリューム内のデータは復元できません"
_MSG[clean_notice_3]="  - 先に実行中のコンテナを停止してください"
_MSG[clean_confirm]="削除を実行しますか？ [y/N]: "
_MSG[clean_cancelled]="キャンセルしました"
_MSG[clean_stopping]="コンテナを削除中..."
_MSG[clean_deleting]="ボリュームを削除中..."
_MSG[clean_vol_failed]="%s（削除失敗 — 使用中の可能性があります）"
_MSG[clean_all_deleted]="✅ %s 個のボリュームをすべて削除しました"
_MSG[clean_partial]="⚠ %s 個削除、%s 個失敗"

# ============================================================
# clean-docker.sh
# ============================================================
_MSG[docker_clean_inside_container]="このスクリプトはコンテナ内から実行できません"
_MSG[docker_clean_header]="Docker リソースクリーンアップ"
_MSG[docker_clean_not_found]="docker コマンドが見つかりません"
_MSG[docker_clean_not_running]="Docker デーモンが起動していません"
_MSG[docker_clean_disk_usage]="現在の Docker ディスク使用量:"
_MSG[docker_clean_disk_usage_after]="クリーンアップ後の Docker ディスク使用量:"
_MSG[docker_clean_select_title]="クリーンアップするリソースを選択:"
_MSG[docker_clean_opt_containers]="停止済みコンテナ (docker container prune)"
_MSG[docker_clean_opt_builder]="ビルドキャッシュ (docker builder prune)"
_MSG[docker_clean_opt_images]="不要イメージ (docker image prune)"
_MSG[docker_clean_opt_networks]="未使用ネットワーク (docker network prune)"
_MSG[docker_clean_opt_volumes]="未使用ボリューム (docker volume prune) ⚠ データ消失リスク"
_MSG[docker_clean_cancelled]="キャンセルしました"
_MSG[docker_clean_running_containers]="停止済みコンテナを削除中..."
_MSG[docker_clean_running_builder]="ビルドキャッシュを削除中..."
_MSG[docker_clean_running_images]="不要イメージを削除中..."
_MSG[docker_clean_running_networks]="未使用ネットワークを削除中..."
_MSG[docker_clean_running_volumes]="未使用ボリュームを削除中..."
_MSG[docker_clean_done_containers]="停止済みコンテナを削除しました"
_MSG[docker_clean_done_builder]="ビルドキャッシュを削除しました"
_MSG[docker_clean_done_images]="不要イメージを削除しました"
_MSG[docker_clean_done_networks]="未使用ネットワークを削除しました"
_MSG[docker_clean_done_volumes]="未使用ボリュームを削除しました"
_MSG[docker_clean_fail_containers]="停止済みコンテナの削除に失敗しました"
_MSG[docker_clean_fail_builder]="ビルドキャッシュの削除に失敗しました"
_MSG[docker_clean_fail_images]="不要イメージの削除に失敗しました"
_MSG[docker_clean_fail_networks]="未使用ネットワークの削除に失敗しました"
_MSG[docker_clean_fail_volumes]="未使用ボリュームの削除に失敗しました"
_MSG[docker_clean_all_done]="✅ 全 %s 件のクリーンアップ操作が完了しました"
_MSG[docker_clean_partial_done]="⚠ %s 件完了、%s 件失敗"
