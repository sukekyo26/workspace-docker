# workspace-docker

## プロジェクトについて

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。モダンな開発ツールがプリインストールされ、Python・Node.js・Docker開発に最適化された環境を提供します。

### 主な特徴

- **最新の開発ツール**: uv（Python）、Volta（Node.js）、Docker CLI、AWS CLI v2
- **永続化対応**: 開発ツールのキャッシュや設定が永続化され、コンテナ再作成後も保持
- **ワークスペース統合**: 複数プロジェクトを一つの開発環境で管理
- **VS Code Dev Container対応**: `.devcontainer`設定により、VS Codeとシームレスに統合
- **ホストDocker活用**: コンテナ内からホストのDockerを安全に利用
- **自動環境検出**: UID/GID/Docker GIDを自動検出し、権限問題を回避
- **UTF-8ロケール**: 日本語を含む多言語テキストを正しく表示

### ワークスペース構造

親ディレクトリ全体がコンテナ内の `/home/<username>/workspace` にマウントされ、複数のプロジェクトを統一環境で開発できます。

```
親ディレクトリ/ (例: /home/user/work/)
├── workspace-docker/  ← Docker設定ファイル (このプロジェクト)
├── python-project/    ← Pythonプロジェクト
├── nodejs-project/    ← Node.jsプロジェクト
└── other-projects/    ← その他のプロジェクト
    ↓ マウント
コンテナ内: /home/<username>/workspace/
├── workspace-docker/
├── python-project/
├── nodejs-project/
└── other-projects/
```

## 利用方法

### 前提条件

#### 必須要件

- Docker Engine がインストールされていること
- （オプション）VS Code + Dev Containers 拡張機能

#### 推奨される事前設定

以下のホスト設定ファイルが**読み取り専用**でコンテナ内にマウントされます（コンテナ内からは変更できません）：

- **`~/.gitconfig`** - Git設定（必須）
- `~/.aws/` - AWS CLI認証情報・設定ファイル（オプション）
- `~/.ssh/` - SSH鍵（オプション）

> **重要**: `~/.gitconfig`が存在しない場合、セットアップスクリプトがエラーになります。最低限、以下のコマンドで基本設定を行ってください：
> ```bash
> git config --global user.name "Your Name"
> git config --global user.email "your.email@example.com"
> ```

#### Dockerのインストール（Ubuntu）

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

※ グループ変更反映のため再ログインが必要です。

### セットアップ手順

1. **セットアップスクリプトの実行**
```bash
bash setup-docker.sh
```

2. **入力が必要な情報**
   - **コンテナ/サービス名**: 
     - 使用可能文字: 英数字（`a-z`, `A-Z`, `0-9`）、ハイフン（`-`）、アンダースコア（`_`）
     - 文字数制限: 1～63文字
     - 例: `dev`, `my-container`, `app_server`
   - **ユーザー名**: 
     - 先頭文字: 小文字の英字（`a-z`）またはアンダースコア（`_`）
     - 使用可能文字: 小文字の英字（`a-z`）、数字（`0-9`）、ハイフン（`-`）、アンダースコア（`_`）
     - 文字数制限: 1～32文字
     - 例: `user`, `dev_user`, `john-doe`

3. **自動検出される情報**
   - **UID/GID**: 現在のユーザーのUID/GIDを自動検出
   - **Docker GID**: ホストのDocker グループGIDを自動検出（`/var/run/docker.sock`から取得）

4. **生成されるファイル**
   - `Dockerfile` - Dockerfileのテンプレートから生成
   - `docker-compose.yml` - docker-compose.ymlのテンプレートから生成
   - `.devcontainer/devcontainer.json` - VS Code Dev Container設定（テンプレートから生成）
   - `.devcontainer/docker-compose.yml` - Dev Container用docker-compose設定（テンプレートから生成）
   - `.envs/<service_name>.env` - 環境変数ファイル（サービス名ごとに管理）
   - `.env` - `.envs/<service_name>.env`へのシンボリックリンク

### 環境変数ファイル（.env）の管理

セットアップスクリプトは、コンテナサービス名ごとに`.envs/<service_name>.env`ファイルを生成します。

#### 複数のコンテナサービスを管理する場合

```bash
# 1つ目のサービス（例: dev）
bash setup-docker.sh
# → .envs/dev.env が生成され、.env → .envs/dev.env のシンボリックリンクが作成される

# 2つ目のサービス（例: prod）
bash setup-docker.sh
# → .envs/prod.env が生成され、.env → .envs/prod.env にシンボリックリンクが更新される

# 使用するサービスを切り替え（方法1: スクリプトを使用）
bash switch-env.sh dev    # devサービスに切り替え
bash switch-env.sh prod   # prodサービスに切り替え

# または、引数なしで対話的に選択
bash switch-env.sh

# 使用するサービスを切り替え（方法2: 手動でシンボリックリンクを変更）
ln -sf .envs/dev.env .env    # devサービスに切り替え
ln -sf .envs/prod.env .env   # prodサービスに切り替え
```

#### .envファイルの内容例

```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
```

### 開発環境の起動方法

#### 方法1: VS Code Dev Container（推奨）

1. VS Codeでこのフォルダを開く
2. コマンドパレット（Ctrl+Shift+P）から「Dev Containers: Open Folder in Container」を実行
3. 自動でコンテナがビルド・起動され、VS Codeがコンテナに接続

#### 方法2: Docker Compose

```bash
# イメージビルド
docker compose build

# コンテナ起動（デタッチモード）
docker compose up -d

# コンテナにアクセス
docker compose exec <サービス名> bash

# コンテナ停止
docker compose down
```

### 開発の流れ

#### Python開発の例

```bash
# Python をインストール
uv python install 3.13

# プロジェクト作成
uv init my-python-project
cd my-python-project

# Python バージョン指定
uv python pin 3.13

# 依存関係追加
uv add requests pandas
uv add --dev pytest black ruff

# スクリプト実行
uv run python main.py

# テスト実行
uv run pytest
```

#### Node.js開発の例

```bash
# Node.js と pnpm をインストール
volta install node@24
volta install pnpm

# プロジェクト作成
pnpm init
pnpm add express

# 開発依存関係
pnpm add -D typescript @types/node

# スクリプト実行
pnpm start

# または直接実行
node app.js
```

## プリインストールアプリケーション

### 開発ツール

| ツール | 用途 | 備考 |
|--------|------|----------------|
| **uv** | Python パッケージ・バージョン管理 | Python 3.8+ |
| **Volta** | Node.js バージョン管理 | Node.js, npm, yarn, pnpm |
| **Docker CLI** | コンテナ操作（ホストのDocker使用） | - |
| **AWS CLI v2** | AWS リソース管理 | - |

### システムツール

- **Git** - バージョン管理
- **curl/wget** - HTTP クライアント
- **vim/nano** - テキストエディタ
- **tree** - ディレクトリ構造表示
- **jq** - JSON プロセッサ
- **build-essential** - C/C++ コンパイラ
- **locales** - ロケール設定（UTF-8対応）
- **各種開発ライブラリ** - SSL, SQLite, XML, etc.

### ロケール設定

- **デフォルトロケール**: `en_US.UTF-8`
- 日本語テキストが正しく表示されるよう自動設定
- Git操作時の日本語ファイル名や差分も正常に表示

### シェル機能

- **Bash補完** - コマンドの自動補完
- **Git統合プロンプト** - ブランチ・状態表示
- **永続化履歴** - コマンド履歴の永続保存

## マウントされているフォルダ

### ワークスペース

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `..` (親ディレクトリ) | `/home/<username>/workspace` | 開発プロジェクト群 |

### 永続化ボリューム

| ボリューム名 | マウント先 | 用途 |
|--------------|------------|------|
| `pip-cache` | `~/.cache/pip` | pip キャッシュ |
| `uv-cache` | `~/.cache/uv` | uv キャッシュ |
| `uv-python` | `~/.local/share/uv` | uv インストール Python |
| `volta-tools` | `~/.volta/tools` | Volta ツール |
| `npm-cache` | `~/.npm` | npm キャッシュ |
| `pnpm-cache` | `~/.cache/pnpm` | pnpm メタデータキャッシュ |
| `pnpm-store` | `~/.local/share/pnpm` | pnpm グローバルストア |
| `bash-history` | `~/.docker_history` | bash 履歴 |

### 読み取り専用マウント

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `~/.aws` | `~/.aws` | AWS 設定・認証情報 |
| `~/.gitconfig` | `~/.gitconfig` | Git 設定 |
| `~/.ssh` | `~/.ssh` | SSH キー（Git認証等に使用） |

### Dev Container専用

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | ホストDocker接続 |

## 注意事項

### セキュリティ

- **Docker ソケット**: ホストのDockerソケットをマウントしているため、コンテナからホストのDocker環境を完全制御可能
- **個人設定**: `~/.aws`、`~/.gitconfig`、`~/.ssh` が読み取り専用でマウントされます
- **SSHキー**: ホストのSSHキーをコンテナ内で共有するため、キーの管理に注意してください
- **機密情報**: 生成された `.env`、`.envs/*.env` にはユーザー情報（UID/GID/Docker GID）が含まれます

### ファイル管理

- **テンプレートファイル必須**: `*.template` ファイルが必要です
- **生成ファイル**: `Dockerfile`、`docker-compose.yml`、`.devcontainer/devcontainer.json`、`.devcontainer/docker-compose.yml`、`.env`、`.envs/` は Git 管理から除外を推奨（自動生成されます）
- **永続化データ**: Docker ボリュームのデータは `docker compose down --volumes` で削除されます
- **環境変数**: `.envs/<service_name>.env`でサービスごとに環境変数を管理。`.env`はシンボリックリンクで切り替え可能

### 開発環境

- **Python**: システムの python3 パッケージは含まれません（uv で管理）
- **Node.js**: Volta でバージョン管理されます（npm、pnpm も含む）
- **pnpm**: 高速パッケージマネージャ、グローバルストアとキャッシュが永続化
- **ポート**: デフォルトで 3000 番ポートがフォワードされます

### 環境切り替え時の注意事項

プロジェクトには環境切り替えスクリプト（`switch-env.sh`）がありますが、**ユーザー名（USERNAME）を変更する場合は必ずコンテナの再ビルドが必要**です。

#### 環境切り替え手順

1. **環境を切り替える**
```bash
bash switch-env.sh <環境名>
```

2. **ユーザー名が変更された場合の必須手順**
```bash
# コンテナを停止・削除
docker compose down

# キャッシュなしで再ビルド（重要！）
docker compose build --no-cache

# 新しい設定で起動
docker compose up -d
```

#### 理由
- Dockerイメージ内でユーザーが作成される際、ビルド時のUSERNAME引数が使用されます
- 環境変数を変更してもビルドキャッシュが残っている場合、古いユーザー名のままとなります
- `--no-cache` オプションでキャッシュを無視して完全に再ビルドする必要があります

### トラブルシューティング

- **権限エラー**: UID/GID が正しく設定されているか確認
- **Docker 接続エラー**: Docker GIDが自動検出されているか確認。`getent group docker | cut -d: -f3`コマンドでホストのDocker GIDを確認できます
- **ボリューム問題**: `docker volume ls` でボリューム状態を確認
- **ユーザー名が古いまま**: 上記の「環境切り替え時の注意事項」を参照してキャッシュなしで再ビルド

## 必要なファイル

- `setup-docker.sh` - セットアップスクリプト
- `switch-env.sh` - 環境切り替えスクリプト
- `Dockerfile.template` - Dockerfileのテンプレート
- `docker-compose.yml.template` - docker-compose.ymlのテンプレート
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container設定のテンプレート
- `.devcontainer/docker-compose.yml.template` - Dev Container用docker-compose設定のテンプレート
