# 変更履歴

このプロジェクトの主な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/spec/v2.0.0.html) に準拠しています。

## [Unreleased]

## [3.1.0] - 2026-01-19

### 追加
- certs/ディレクトリからの自動CA証明書インストール機能（環境変数サポート付き）
- cargo-lambdaクロスコンパイル用のZigツールチェーン（オプションインストール）
- Deno（~/.deno）、Bun（~/.bun）、Go（~/go）ワークスペース用の永続ボリューム
- CargoとRustupの永続ボリューム（~/.cargo、~/.rustup）を含むRustツールチェーンサポート
- workspace-docker/config/.bashrc_custom経由のカスタムbash設定サポート
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
- エラーハンドリングライブラリ（lib/errors.sh）
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
- lib/errors.sh関数によりエラーメッセージを改善

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
