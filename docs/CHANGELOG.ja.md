# 変更履歴

このプロジェクトの主な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/spec/v2.0.0.html) に準拠しています。

## [Unreleased]

### 追加
- `curl | sh` インストールスクリプトの SHA256 整合性検証 — 5 プラグイン（proto, uv, rust, claude-code, copilot-cli）と devcontainer CLI で、ダウンロードしたスクリプトをピン止めされたチェックサムで検証してから実行
- プラグインスキーマに `install_script_sha256` フィールド追加（インストールスクリプトのチェックサム検証用）
- Python コードカバレッジ計測 — `tests/run_coverage.sh` でローカルカバレッジレポート生成（`coverage.py` 使用、現在 `lib/` は 78%）
- JSON Schema バリデーションテストスイート（36 pytest ケース）— `workspace.toml` とプラグイン TOML スキーマの正常入力受理・不正入力拒否を検証

### 修正
- `devcontainer CLI` の PATH 解決 — CLI がインストール済みだが PATH にない場合、`~/.devcontainers/bin` を自動追加。自動インストール前にユーザーに確認。シェルプロファイルへの永続化ヒントを表示

## [4.1.2] - 2026-03-09

### 追加
- `workspace.toml` スキーマで `[devcontainer]` セクションをサポート — `devcontainer.json` のプロパティをディープマージで上書き可能に（スキーマバリデーションエラーが発生しなくなった）
- `workspace.toml` の部分定義をサポート — `[container]` セクションが未定義の場合、`setup-docker.sh` がインタラクティブモードでコンテナ設定を行い、既存の `[plugins]`、`[ports]`、`[vscode]`、`[volumes]`、`[devcontainer]` セクションを保持
- プラグインのプリセレクション — `workspace.toml` に `[plugins]` が定義済みの場合、TUI チェックボックスの初期値がプラグイン TOML のデフォルトではなく既存設定を反映

## [4.1.1] - 2026-03-08

### 修正
- `workspace.toml` の `[volumes]` セクションで定義したボリュームのディレクトリが `Dockerfile` 内で `mkdir -p` と `chown` されるように修正 — これまではコンテナ初回起動時に root 権限でディレクトリが作成されていた

## [4.1.0] - 2026-03-08

### 追加
- `clean-docker.sh`: 対話式 Docker リソースクリーンアップスクリプト — マルチセレクト TUI メニューで削除対象リソースを選択（停止済みコンテナ、ビルドキャッシュ、不要イメージ、未使用ネットワーク、未使用ボリューム）。クリーンアップ前後のディスク使用量を表示。`--lang` オプション対応。
- 全シェルスクリプト（`setup-docker.sh`、`clean-volumes.sh`、`rebuild-container.sh`、`generate-workspace.sh`）に `--lang` オプション追加 — `WORKSPACE_LANG` 環境変数の代替として言語選択が可能に
- `docs/setup.md` / `docs/setup.ja.md`: `[volumes]` パスでの `${USERNAME}` 変数置換についてのドキュメントセクション追加
- `toml_parser.py` に `sync-schema` コマンド追加 — `setup-docker.sh` 実行時に `workspace.schema.json` の plugins enum を `plugins/` ディレクトリから自動同期
- `tests/unit/plugins/test_starship.sh`: starship プラグインのユニットテスト追加（チェックサム検証・TLS 強制）
- `README.md` / `docs/README.ja.md`: `--init` / `--init --yes` フラグの説明追加、taplo VS Code 拡張機能の記載追加
- `workspace.toml` とプラグイン TOML のランタイム JSON Schema バリデーション追加 — `setup-docker.sh` 実行時に不正な設定を検出・拒否（`jsonschema` 使用）
- `schemas/plugin.schema.json`: プラグイン TOML バリデーション用 JSON Schema
- 生成ファイル（`Dockerfile`、`docker-compose.yml`）に自動生成ヘッダーコメント追加（`# Auto-generated from workspace.toml — do not edit directly.`）
- `README.md` と `docs/README.ja.md` の上部に言語切替リンクを追加（英語⇔日本語）
- `config/workspace-settings.json.example`: Go、Rust、Java、C#、C、C++、Swift、Kotlin、PHP、Makefile の `tabSize: 4` 設定を追加
- i18n フレームワーク（`lib/i18n.sh`, `locale/en.sh`, `locale/ja.sh`）— 全ユーザー向けメッセージを `WORKSPACE_LANG` 環境変数で英語/日本語切り替え可能に
- `generators.py`: プラグイン競合検出追加 — 排他的プラグイン（例: `starship` + `custom-ps1`）の同時有効化を `[metadata].conflicts` で検出・エラー終了
- `schemas/workspace.schema.json`: `workspace.toml` の JSON Schema 追加 — [taplo](https://taplo.tamasfe.dev/) による IDE 補完・静的バリデーションを実現
- `.taplo.toml`: taplo 設定ファイル（スキーマを `workspace.toml` と `workspaces/*.toml` に紐付け）
- `generators.py`: ボリュームパス重複チェック追加 — プラグインと `workspace.toml` で異なる名前が同一コンテナパスにマウントされる場合をエラー検出
- `generators.py`: ボリュームパス重複を警告+統合に変更（エラーではなくなった）— プラグイン間のボリューム名重複は引き続きエラー
- `schemas/plugin.schema.json`: ボリュームパスを `/home/${USERNAME}/<name>`（ホームディレクトリ直下のみ）に制限
- `github-cli` プラグイン: ボリュームを `gh-config`（`~/.config/gh`）から `config`（`~/.config`）に変更（ホーム直下パス正規化）
- `tests/unit/lib/test_colors.sh`: `lib/colors.sh` のユニットテスト追加（NO_COLOR モード・ANSI エスケープ形式）
- `tests/unit/lib/test_tui.sh`: `lib/tui.sh` のユニットテスト追加（グローバル状態初期化・関数定義確認・カラー継承）
- `starship` プラグイン: クロスシェルプロンプト（チェックサム検証付き、`custom-ps1` の代替）
- `custom-ps1` プラグイン: PS1 プロンプト設定をプラグインに抽出（starship で置換可）
- `rust` プラグイン: rustup による Rust ツールチェーン（cargo, clippy, rustfmt）と永続ボリューム
- `go` プラグイン: Go 言語（チェックサム検証・GOPATH ボリューム付き）
- `lazygit` プラグイン: Git 操作用ターミナル UI（チェックサム検証付き）
- プロジェクトの Docker named volume を全削除する `clean-volumes.sh` スクリプト
- 事前定義ワークフロー: `setup-docker.sh --init` の前に `workspace.toml` を作成し `[apt]`、`[vscode]`、`[volumes]` セクションを事前定義可能に
- `select_multi` に `q` キーによるキャンセル機能を追加

### 変更
- **破壊的**: プラグインボリューム形式を `[volumes]` セクション（名前-パスペア）から `[install]` 内の `volumes = ["パス"]` 配列に変更 — ボリューム名はパスから自動導出（basename の先頭ドット除去、例: `~/.aws` → `aws`）
- `starship` プラグイン: 永続的な設定保存のため `~/.config` ボリューム宣言を追加
- `custom-ps1` プラグイン: デフォルトを `true` から `false` に変更（オプション扱い、デフォルトでは無効）
- `clean-volumes.sh`: devcontainer 互換性のため `docker compose down` の代わりに Docker ラベルベースのコンテナ検索に変更
- `docs/reference.md` / `docs/reference.ja.md`: プラグインリスト更新（全14個）、`--lang` オプションのドキュメント追加、コアスクリプトに `clean-volumes.sh` を追加、プラグイン作成ガイドを新ボリューム配列形式に更新
- README の利用可能プラグインリストをリファレンスドキュメントへのリンクに変更（README 肥大化防止）
- README から「品質保証」の特徴行を削除（内部詳細でありユーザー向け機能ではない）
- `_uv_python()`: `uv run` に `--no-dev` フラグを追加—エンドユーザー環境で dev 依存のインストールをスキップ
- `generators.py`: 生成される `docker-compose.yml` のシーケンスアイテムのインデントを修正（`args`、`environment`、`volumes` のリスト項目が適切にインデントされるように）
- `generators.py`: 生成される `.devcontainer/docker-compose.yml` の過剰なコメントを最小限に削減
- `generators.py`: `workspace.toml` の `[volumes]` と有効化プラグインのボリューム名が重複する場合はエラーを出力するように
- `generators.py`: プラグイン TOML データをキャッシュして二重読み込みを解消（DRY）
- `generators.py`: 有効化されたプラグイン ID が見つからない場合に stderr に WARNING を出力
- `github-cli` プラグイン: GPG キーのダウンロードを `wget` から `curl` に変更
- `config/.bashrc_custom.example` から Rust/Cargo の例を削除（rust プラグインで管理）
- **破壊的**: uv管理のPythonプロジェクトに移行 — ホストに `uv` が必要
- **破壊的**: Dockerボリューム名に `COMPOSE_PROJECT_NAME` プレフィックスを追加（`{project}_{service}_{volume}`）
- **破壊的**: 全シェルスクリプト・TOMLファイルを2スペースインデントに変換
- `docker-cli` プラグイン: Ubuntu コードネーム取得を `lsb-release` から `/etc/os-release` に変更
- i18n ポリシー変更: ユーザー向け出力（TUI、echo）とコードコメントを日本語から英語に変更
- 生成される Dockerfile テンプレートから日本語コメントを削除
- 全 `python3` 呼び出しを `_uv_python()` ヘルパー経由の `uv run python` に置換
- `check_python3()` を `check_uv()` にリネーム
- PyYAML を dev dependency-group からプロジェクト依存に移動
- `config/workspace-settings.json` を `.example` にリネーム
- 設定ファイルから個人設定（`localeOverride`）を削除

### 修正
- `clean-volumes.sh`: 停止済みコンテナ（`docker ps -aq`）も削除してからボリューム削除を実行するように修正 — 停止済みコンテナがボリューム参照を保持し `docker volume rm` が失敗していた
- `pyproject.toml`: ruff lint 設定の非推奨 `TCH` を `TC` に修正（ruff 0.5+ でのリネーム対応）
- 生成される TOML 配列（例: `[vscode].extensions`）のインデントを2スペースから4スペースに修正（TOML 規約に準拠）
- `validate_service_name` のパターンを JSON Schema と統一（`^[a-z][a-z0-9_-]*$`）— 大文字や数字/アンダースコア開始の名前を一貫して拒否
- `rust` プラグイン: `rustup-init` の `--component` フラグを個別指定に修正（CI ビルド失敗修正）
- `clean-volumes.sh`: Docker デーモン起動確認（`docker info`）を追加
- `clean-volumes.sh` / `rebuild-container.sh`: エラー出力を `logging.sh` に統一
- 重複テストファイル（`test_generators.sh`、`test_errors.sh`）を削除し二重実行を解消
- `check_devcontainer_cli` の trap 上書きを修正（呼び出し元の EXIT trap を保護）
- `validate_symlink` のパストラバーサル脆弱性を修正（末尾スラッシュによるプレフィックスガード）
- `colors.sh` に `set -uo pipefail` を追加（他の lib ファイルとの一貫性）
- `.env` 生成を `printf` に変更しシェル展開による値の破損を防止
- `_parse_toml_output` の nameref スコープ汚染検証テストを追加
- `set -e` 設計意図を文書化: lib ファイルは source されるため `set -uo pipefail`（`-e` なし）を使用
- `CURRENT_LOG_LEVEL` を export しサブシェルでログレベルが反映されるように修正
- `generators.py` の `open()` に `encoding="utf-8"` を明示
- `_run_generator` が前回中断時の古い一時ファイルをクリーンアップするように改善
- CI の docker-build ジョブに `uv` セットアップを追加
- `read_env_var` がキー未検出時に非ゼロを返すように修正（`||` によるフォールバックが機能するように）
- `toml_parser.py` の `list-plugins` の例外キャッチを `Exception` から `(TOMLDecodeError, OSError)` に具体化
- 全プラグインのダウンロードコマンドに TLS 1.2 を強制（`--proto '=https' --tlsv1.2`）（docker-cli, github-cli, zig）

## [4.0.0] - 2026-03-04

### 追加
- **プラグインアーキテクチャ**: `plugins/*.toml` TOMLファイルによる拡張可能なツール選択
  - TOMLパーサーヘルパー（`lib/toml_parser.py`）— Python 3.11+ `tomllib`使用
  - プラグインローディングライブラリ（`lib/plugins.sh`）— Dockerfileスニペット生成
  - 既存ツール用プラグイン定義: `proto`, `aws-cli`, `aws-sam-cli`, `copilot-cli`, `claude-code`, `docker-cli`, `github-cli`, `zig`
- **workspace.toml**: 対話式セットアップに代わる単一TOML設定ファイル
  - `[container]` セクション — サービス名、ユーザー名、Ubuntuバージョン
  - `[plugins]` セクション — ツール選択
  - `[apt]` セクション — 追加システムパッケージ
  - `[ports]` セクション — ポートフォワーディング
- `workspace.toml`の`[apt].packages`による追加aptパッケージサポート
- `workspace.toml`の`[ports].forward`による設定可能なポートフォワーディング
- 有効なプラグインに基づく条件付きDockerボリューム生成
- 初回セットアップ時の`.bashrc_custom`スケルトンの自動コピー
- ベースaptパッケージを`config/apt-base-packages.conf`に外部化
- 新プラグイン: `copilot-cli`（GitHub Copilot CLI）、`claude-code`（Anthropic Claude Code）
- curlセキュリティ強化: curl-pipe-shパターンの排除と全curlコマンドへの`-f`フラグ追加
- デフォルトシステムユーティリティに`uuid-runtime`パッケージを追加
- システムパッケージに`python3`、`python3-pip`、`python3-venv`、`file`、`patch`、`gettext-base`を追加
- インタラクティブワークスペースジェネレータスクリプト（`generate-workspace.sh`）
- DevContainer管理スクリプト（`rebuild-container.sh`、`lib/devcontainer.sh`）
- 生成ファイルのスナップショット回帰テスト
- 生成Dockerfile、YAML、JSONの構造的妥当性テスト
- より信頼性の高い検証のためのソースgrep方式から実行ベーステストへの移行
- エンドツーエンドファイル生成パイプラインの統合テスト
- プラグインTOML構造検証テストスイート

### 変更
- **破壊的変更**: `setup-docker.sh`をプラグインベースアーキテクチャで書き直し
- **破壊的変更**: `generators.sh`をプラグインベース生成パイプラインで書き直し
- **破壊的変更**: `switch-env.sh`と`.envs/`マルチ環境管理を廃止
- `Dockerfile.template`を単一プラグインプレースホルダー（`{{PLUGIN_INSTALLS}}`）使用に簡素化
- protoをハードコードからプラグインシステムに移行（`plugins/proto.toml`）
- ハードコードのaptパッケージを`Dockerfile.template`から`config/apt-base-packages.conf`に移動
- `Dockerfile.template`を約62行（約120行から）に最小化—プレースホルダーとベースインフラのみ
- デフォルトツールを最小セット（proto + Docker CLIのみ）に変更
- テンプレート置換をawkに統一（sedベースのアプローチを削除）
- プラグインベースアーキテクチャ用にテストスイートを書き直し
- CIワークフローをプラグインベースアーキテクチャ用に更新、Hadolintを生成Dockerfileに適用
- `.shellcheckrc`設定により全ShellCheckスタイルレベル警告を解消
- READMEをプラグインアーキテクチャとworkspace.toml設定に合わせて完全書き直し
- READMEをコンパクトなQuick Start（ルート）と詳細ガイド（`docs/`）に分割
  - `docs/setup.md` / `docs/setup.ja.md` — セットアップ・設定ガイド
  - `docs/usage.md` / `docs/usage.ja.md` — 開発ワークフロー、コマンド集、マウントディレクトリ
  - `docs/reference.md` / `docs/reference.ja.md` — プリインストール済みソフト、プロジェクトファイル
- PyenvリファレンスをPython設定例でprotoに置換

### 削除
- `switch-env.sh`マルチ環境スイッチャー
- `.envs/`ディレクトリ（環境プロファイル用）
- `test.sh`ラッパースクリプト（`tests/run_all.sh`に置換）
- デッドコード: `validate_package_manager`関数
- テンプレート置換からの非推奨バージョンフィールド
- 機能しない`chat.instructionsFilesLocations`設定

### 修正
- Docker GID検出でのGID 999フォールバックを削除
- APT_EXTRA_PACKAGESプレースホルダー置換時の先頭空白の処理
- APT_EXTRA_PACKAGESプレースホルダー置換後のlocale-genの復元
- CIテンプレート検証のYAMLパースエラー

## [3.1.0] - 2026-01-19

### 追加
- certs/ディレクトリからの自動CA証明書インストール機能（環境変数サポート付き）
- cargo-lambdaクロスコンパイル用のZigツールチェーン（オプションインストール）
- Deno（~/.deno）、Bun（~/.bun）、Go（~/go）ワークスペース用の永続ボリューム
- CargoとRustupの永続ボリューム（~/.cargo、~/.rustup）を含むRustツールチェーンサポート
- config/.bashrc_custom経由のカスタムbash設定サポート
- システムパッケージにネットワーク診断ユーティリティ（ping、traceroute、dnsutils）を追加
- システムユーティリティにbc（任意精度計算機）パッケージを追加
- 言語ランタイム用の新しい永続ボリュームのテスト検証
- CA証明書ディレクトリ構造用のcerts/.gitkeep
- カスタムbash設定のテンプレートとしてconfig/.bashrc_custom.example

### 変更
- bashヒストリーを.docker_historyからXDG準拠の~/.local/state/.bash_history_dockerに移動
- カスタムbash設定を~/.bashrc_customからworkspace-docker/config/に移動し、ホスト側での編集を容易化
- devcontainer.jsonのVS Code拡張機能推奨を更新
- setup-docker.shに自動CA証明書設定プロンプトを追加して強化
- switch-env.shをCA証明書インストールスクリプトの再生成に対応
- test.shをCA証明書セットアップと永続ボリュームの検証に改善

### 削除
- ~/.gitconfigマウント（Dev Containerが自動的に~/.gitconfigをコピーするため）
- ~/.git-credentialsマウント（Dev Containerの自動処理により不要になったため）

### 修正
- setup-docker.shのチルダ展開に関するShellCheck SC2088警告を修正

## [3.0.0] - 2026-01-01

### 変更
- **破壊的変更**: シンプル/カスタムセットアップモード選択を廃止 - ツールインストールを直接選択する方式に変更
- **破壊的変更**: 環境変数からSETUP_MODEを削除
- **破壊的変更**: Dockerfile.custom.templateをDockerfile.templateに統合、プレースホルダーベースの生成方式に変更
- セットアップフローを簡素化、protoは常にインストールされ、他のツールは個別に選択可能（デフォルト: Yes）
- すべてのツール選択プロンプトのデフォルトをYesに変更し、より高速なセットアップを実現
- テンプレートシステムを統一 - すべての構成で単一のDockerfile.templateを使用

### 削除
- Dockerfile.custom.template（Dockerfile.templateに統合）
- docker-compose.custom.template（不要になったため削除）
- lib/validators.shからvalidate_setup_mode関数を削除
- .envファイルからSETUP_MODE変数を削除
- READMEファイルからモード関連のドキュメントを削除

### 修正
- コードの複雑さを754行分削減
- 合理化されたセットアッププロセスによりユーザーエクスペリエンスを改善
- シンプルモードとカスタムモードの混乱を解消

## [2.2.0] - 2025-12-27

### 追加
- 一元化されたバージョン設定ファイル（lib/versions.conf）
- 共有ジェネレータ関数ライブラリ（lib/generators.sh）
- 入力検証ライブラリ（lib/validators.sh）
- エラーハンドリングライブラリ（lib/logging.sh）
- 安全な環境変数パース機能（read_env_var）
- シンボリックリンク検証機能（validate_symlink）
- フォールバックロジック付きDocker GID検出機能（detect_docker_gid）
- スコープ分離のためDockerボリューム名にサービス名プレフィックスを追加
- 開発環境にShellCheckパッケージを追加
- GitHub Actions CI/CDワークフロー追加:
  - ShellCheck静的解析
  - 自動テスト実行
  - テンプレート検証
  - HadolintによるDockerfile Lint
  - Dockerビルド検証
- 包括的なテストカバレッジ追加:
  - バリデータ関数
  - エラーハンドリング関数
  - ボリュームスコープ
  - ユーティリティ関数

### 変更
- setup-docker.shを共有ジェネレータライブラリ使用にリファクタリング
- switch-env.shを共有ジェネレータライブラリ使用にリファクタリング
- 全スクリプトで一元化された検証およびエラーハンドリングライブラリを使用
- NVMバージョンをGitHub APIから自動取得（最新リリース）
- Dockerfileレイヤーを--no-install-recommendsと改善されたクリーンアップで最適化
- テストスイートをCI環境で存在しないファイルをスキップするよう更新
- Hadolintルールを開発環境互換性のため設定
- Ubuntuバージョン管理をlib/versions.confに一元化
- 英語版READMEから重複セクションを削除

### 修正
- 全シェルスクリプトのShellCheck警告を解決
- サービス名プレフィックスによりボリューム名の競合を防止
- lib/logging.sh関数によりエラーメッセージを改善

## [2.1.0] - 2025-12-27

### 追加
- アーキテクチャ自動検出機能付きAWS SAM CLI（x86_64/aarch64対応）
- Dockerボリュームによる~/.awsのAWS設定永続化
- 設定と認証ストレージを永続化するGitHub CLI (gh)
- マルチルートワークスペース生成スクリプト（generate-workspace.sh）
- READMEに包括的なマルチルートワークスペースドキュメント
- AWS CLIとGitHub CLI設定用のボリュームサポート

### 変更
- AWS CLI設定がバインドマウントからDockerボリュームでの永続化に変更
- Dockerfileテンプレートでツールインストール順序を改善して再構成
- READMEにAWS SAM CLIとGitHub CLIのセットアップ手順を追加

### 修正
- ボリュームベースの永続化によりAWS認証情報パスとパーミッション問題を解決

## [2.0.0] - 2025-11-25

### 追加
- 柔軟なパッケージマネージャー選択が可能なカスタムセットアップモード
- Pythonパッケージマネージャーオプション: uv、poetry、pyenv+poetry、mise、またはなし
- Node.jsバージョンマネージャーオプション: Volta、nvm、fnm、mise、またはなし
- mise（多言語対応バージョン管理ツール）のサポート
- カスタムモード用のDockerfile.custom.template
- 全パッケージマネージャー用ボリュームを含むdocker-compose.custom.template
- 8つの高度な検証チェックを含む包括的なテストスイート:
  - テンプレートプレースホルダーの整合性検証
  - 生成ファイル内の未置換プレースホルダー検出
  - docker-compose.yml構文検証
  - シェルスクリプト構文チェック
  - 環境変数ファイルフォーマット検証
  - パッケージマネージャー関数のテスト
  - モード対応ボリュームマウントポイント検証（ノーマル/カスタム）
  - .gitignoreパターンカバレッジチェック
- テストスキップ機能と独立したカウンター
- 条件付きpython3インストール（poetryとpyenv+poetryのみ）
- poetry、pyenv、nvm、fnm、mise用のボリュームサポート
- switch-env.shで環境切り替え時にDockerfileとdocker-compose.ymlを再生成
- Dockerfileテンプレートに必須システムパッケージ（39パッケージ）を追加
- README（英語版・日本語版）にパッケージマネージャーの詳細ドキュメント

### 変更
- **破壊的変更**: setup-docker.shの対話形式を自動インストールから柔軟なパッケージマネージャー選択方式に変更
- **破壊的変更**: .envs/*.envファイル構造にPYTHON_MANAGERとNODEJS_MANAGER変数を追加
- **破壊的変更**: ノーマルモードとカスタムモードをサポートする設定システムに再設計
- switch-env.shがSETUP_MODEを検証し、全設定ファイルを再生成するように変更
- README.mdとdocs/README.ja.mdを包括的なパッケージマネージャー情報で更新
- ボリュームマウントディレクトリは選択に関わらず全パッケージマネージャー用に作成されるように変更
- docker-compose.yml.template（ノーマルモード）にもデータ保護のため全パッケージマネージャー用ボリュームを追加

### 修正
- switch-env.shが選択されたツールに基づいてDockerfileとdocker-compose.ymlを適切に再生成するように修正

## [1.0.0] - 2025-11-09

### 追加
- Docker ベースの Ubuntu 開発環境
- Python (uv)、Node.js (Volta)、Docker CLI、AWS CLI v2 のサポート
- VS Code Dev Container 統合
- .envs ディレクトリによる複数環境管理
- 自動 UID/GID/Docker GID 検出
- 開発ツール用の永続ボリュームサポート
- switch-env.sh での環境変数検証
- SSH マウントセキュリティドキュメント
- 日本語テキスト表示のための UTF-8 ロケール設定
- ビジュアルファイルステータスインジケータを備えたプロジェクト検証用テストスクリプト (test.sh)
- README での包括的な Docker コマンドリファレンス
- バージョン追跡のための CHANGELOG.md
- ライセンス (MIT License)
