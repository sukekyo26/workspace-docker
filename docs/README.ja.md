# workspace-docker

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。proto（多言語バージョンマネージャー）とプラグインベースのツール選択システムを備えています。

## 主な特徴

- **プラグインアーキテクチャ**: `plugins/*.toml`による拡張可能なツール選択 — TOMLファイルの編集でツールの追加・カスタマイズが可能
- **TOML設定ファイル**: すべての設定が`workspace.toml`に集約 — 編集して再実行するだけで再生成
- **proto**: Python、Node.js、Bun、Deno、Go、Rust、および100以上のツールに対応した統合的な多言語バージョンマネージャー
- **カスタムCA証明書**: 企業プロキシ/VPN環境向けのカスタムCA証明書の自動インストール
- **永続化対応**: protoツールや設定が永続化され、コンテナ再作成後も保持
- **VS Code Dev Container対応**: `.devcontainer`設定により、VS Codeとシームレスに統合
- **品質保証**: 8つのテストスイートとGitHub Actions CI/CD（ShellCheck、Hadolint、スナップショットテスト）

## クイックスタート

### 前提条件

- Dockerがホストマシンにインストールされていること
- （オプション）VS Code + Dev Containers 拡張機能

### セットアップ

```bash
# 1. セットアップスクリプトを実行（対話式 — workspace.tomlと全設定ファイルを生成）
bash setup-docker.sh

# 2. 再設定時はworkspace.tomlを編集して再実行
vim workspace.toml
bash setup-docker.sh
```

#### workspace.toml

```toml
[container]
service_name = "dev"
username = "devuser"
ubuntu_version = "24.04"

[plugins]
enable = ["aws-cli", "aws-sam-cli", "docker-cli", "github-cli"]

[apt]
extra_packages = ["ripgrep", "fd-find"]

[ports]
forward = [3000]
```

利用可能なプラグイン: `aws-cli`, `aws-sam-cli`, `docker-cli`, `github-cli`, `zig`（`plugins/*.toml`で定義）

### 開発環境の起動

**VS Code Dev Container（推奨）:**

1. VS Codeでこのフォルダを開く
2. コマンドパレット（Ctrl+Shift+P）から「開発コンテナ: コンテナでフォルダーを開く」を実行
3. 自動でコンテナがビルド・起動され、VS Codeがコンテナに接続

**Docker Compose（手動）:**

```bash
docker compose up -d --build
docker compose exec <サービス名> bash
```

### ワークスペース構造

親ディレクトリがコンテナ内の `/home/<username>/workspace` にマウントされます：

```
親ディレクトリ/
├── workspace-docker/  ← このプロジェクト
├── python-project/    ← 開発プロジェクト
├── nodejs-project/
└── other-projects/
    ↓ マウント
コンテナ内: /home/<username>/workspace/
├── workspace-docker/
├── python-project/
├── nodejs-project/
└── other-projects/
```

## ドキュメント

| ドキュメント | 説明 |
|-------------|------|
| [セットアップガイド](setup.ja.md) | 詳細設定、CA証明書、マルチルートWS、トラブルシューティング |
| [使い方ガイド](usage.ja.md) | 開発ワークフロー、コマンド集、マウントディレクトリ |
| [リファレンス](reference.ja.md) | プリインストール済みソフト、システムパッケージ、プロジェクトファイル |
| [English README](../README.md) | 英語版ドキュメント |
| [Setup Guide](setup.md) | Setup guide (English) |
| [Usage Guide](usage.md) | Usage guide (English) |
| [Reference](reference.md) | Reference (English) |
| [変更履歴](../CHANGELOG.md) | バージョン履歴 |

## ライセンス

このプロジェクトは[MIT License](../LICENSE)の下でライセンスされています。
