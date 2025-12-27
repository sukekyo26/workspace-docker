# 変更履歴

このプロジェクトの主な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/spec/v2.0.0.html) に準拠しています。

## [Unreleased]

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
