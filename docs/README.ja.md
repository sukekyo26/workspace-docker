# workspace-docker

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。モダンな開発ツールがプリインストールされ、Python・Node.js・Docker開発に最適化された環境を提供します。

## 主な特徴

- **柔軟なセットアップ**: ノーマル（クイックスタート）またはカスタム（ソフトウェア選択）モード
- **最新の開発ツール**: uv（Python）、Volta（Node.js）、Docker CLI、AWS CLI v2、AWS SAM CLI、Slack CLI、GitHub CLI
- **永続化対応**: 開発ツールのキャッシュや設定が永続化され、コンテナ再作成後も保持
- **ワークスペース統合**: 複数プロジェクトを一つの開発環境で管理
- **VS Code Dev Container対応**: `.devcontainer`設定により、VS Codeとシームレスに統合
- **ホストDocker活用**: コンテナ内からホストのDockerを安全に利用
- **自動環境検出**: UID/GID/Docker GIDを自動検出し、権限問題を回避
- **UTF-8ロケール**: 日本語を含む多言語テキストを正しく表示

## ワークスペース構造

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

**必須要件:**
- Docker Engine がインストールされていること
- AWS SAM CLIの`sam local`を使う場合はDockerが必須です（ローカルでLambda関数やAPIを実行するため）
- `~/.gitconfig` ファイル（下記参照）

**オプション:**
- VS Code + Dev Containers 拡張機能
- Slack CLIを使用する場合は、`SLACK_BOT_TOKEN`や`SLACK_USER_TOKEN`等のトークンを環境変数に設定するか、`slack` CLIの認証フローで設定してください

以下のホスト設定ファイルが**読み取り専用**でコンテナ内にマウントされます（コンテナ内からは変更できません）：

- **`~/.gitconfig`** - Git設定（必須）
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

2. **セットアップモードの選択**
   - **ノーマル (1)**: 推奨ツールがプリインストールされたクイックスタートモード
   - インストール内容: Docker CLI, AWS CLI v2, AWS SAM CLI, Slack CLI, GitHub CLI, uv, Volta
     - Python & Node.js開発に推奨
     - 最も早く開始できる方法
   - **カスタム (2)**: インストールするソフトウェアを選択
     - インストールするツールを細かく制御可能
     - 不要なツールを除外してイメージサイズを削減
     - 注意: ソフトウェアの選択に関わらず、すべてのツール用のキャッシュディレクトリとボリュームは作成されます

3. **入力が必要な情報**
   - **コンテナ/サービス名**:
     - 使用可能文字: 英数字（`a-z`, `A-Z`, `0-9`）、ハイフン（`-`）、アンダースコア（`_`）
     - 文字数制限: 1～63文字
     - 例: `dev`, `my-container`, `app_server`
   - **ユーザー名**:
     - 先頭文字: 小文字の英字（`a-z`）またはアンダースコア（`_`）
     - 使用可能文字: 小文字の英字（`a-z`）、数字（`0-9`）、ハイフン（`-`）、アンダースコア（`_`）
     - 文字数制限: 1～32文字
     - 例: `user`, `dev_user`, `john-doe`

4. **ソフトウェアの選択**（カスタムモードのみ）
   - **Docker CLI**: コンテナ操作 (y/n)
   - **AWS CLI v2**: AWSリソース管理 (y/n)
   - **AWS SAM CLI**: サーバーレスLambda関数のローカルでのビルド、テスト、実行 (y/n)
   - **Slack CLI**: Slackワークスペース操作とAPI連携のためのCLIツール (y/n)
   - **GitHub CLI**: リポジトリ管理、プルリクエスト、Issueおよびワークフロー操作のためのCLI (y/n)
   - **Pythonパッケージ管理ツール**: 以下から選択:
     1. **uv**（推奨）: 高速、オールインワンのPythonパッケージ・バージョン管理
     2. **poetry**: プロジェクト中心の依存関係管理
     3. **pyenv + poetry**: バージョン管理（pyenv）+ 依存関係管理（poetry）
     4. **mise**: 多言語対応バージョン管理ツール（Python、Node.js等）
     5. **none**: Pythonツールをスキップ
   - **Node.jsバージョン管理ツール**: 以下から選択:
     1. **Volta**（推奨）: プロジェクトベースの自動バージョン切り替え
     2. **nvm**: 伝統的で広く使われているNode.jsバージョン管理ツール
     3. **fnm**: Fast Node Manager（Rust製、nvmの高速代替）
     4. **mise**: 多言語対応バージョン管理ツール（Python、Node.js等）
     5. **none**: Node.jsツールをスキップ

5. **自動検出される情報**
   - **UID/GID**: 現在のユーザーのUID/GIDを自動検出
   - **Docker GID**: ホストのDocker グループGIDを自動検出（`/var/run/docker.sock`から取得）

6. **生成されるファイル**
   - `Dockerfile` - テンプレート（ノーマルまたはカスタム）から生成
   - `docker-compose.yml` - テンプレート（ノーマルまたはカスタム）から生成
   - `.devcontainer/devcontainer.json` - VS Code Dev Container設定（テンプレートから生成）
   - `.devcontainer/docker-compose.yml` - Dev Container用docker-compose設定（テンプレートから生成）
   - `.envs/<service_name>.env` - 環境変数ファイル（サービス名ごとに管理、ソフトウェア選択フラグを含む）
   - `.env` - `.envs/<service_name>.env`へのシンボリックリンク

   > **環境切り替え時**: `switch-env.sh`を使用すると、`.env`のシンボリックリンクとともに`.devcontainer`ファイルも自動的に再生成されます

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

# 注意: スクリプトは自動的に.devcontainerファイルも再生成します

# 使用するサービスを切り替え（方法2: 手動でシンボリックリンクを変更）
ln -sf .envs/dev.env .env    # devサービスに切り替え
ln -sf .envs/prod.env .env   # prodサービスに切り替え
```

#### .envファイルの内容例

**ノーマルモード:**
```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
SETUP_MODE=1
INSTALL_DOCKER=true
INSTALL_AWS_CLI=true
PYTHON_MANAGER=uv
NODEJS_MANAGER=volta
```

**カスタムモード:**
```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
SETUP_MODE=2
INSTALL_DOCKER=true
INSTALL_AWS_CLI=false
PYTHON_MANAGER=poetry
NODEJS_MANAGER=nvm
```

### 開発環境の起動方法

#### 方法1: VS Code Dev Container（推奨）

**単一プロジェクトの場合：**
1. VS Codeでこのフォルダを開く
2. コマンドパレット（Ctrl+Shift+P）から「Dev Containers: Open Folder in Container」を実行
3. 自動でコンテナがビルド・起動され、VS Codeがコンテナに接続

**マルチルートワークスペース（複数プロジェクト）の場合：**

複数のプロジェクトを同時に独立した設定で作業したい場合は、マルチルートワークスペース機能を使用します：

1. ワークスペースファイルを生成（初回のみ）：
   ```bash
   ./generate-workspace.sh
   ```

2. Dev Containerに接続後、コンテナ内からワークスペースファイルを開く：
   - コマンドパレット（Ctrl+Shift+P）から「File: Open Workspace from File...」を選択
   - `/home/<username>/workspace/workspace-docker/multi-project.code-workspace` を選択

これにより、すべてのプロジェクトが個別のワークスペースフォルダとして開き、それぞれ独立した設定で作業できます。

詳細は下記の[マルチルートワークスペースのサポート](#マルチルートワークスペースのサポート)セクションを参照してください。

#### 方法2: Docker Compose

```bash
# イメージビルド
docker compose build

# キャッシュなしでビルド（環境変数変更時など）
docker compose build --no-cache

# コンテナ起動（デタッチモード）
docker compose up -d

# ビルドと起動を同時に実行
docker compose up -d --build

# コンテナにアクセス
docker compose exec <サービス名> bash

# ログの確認
docker compose logs
docker compose logs -f  # リアルタイムで表示

# コンテナの状態確認
docker compose ps

# コンテナ停止
docker compose down

# コンテナ停止とボリューム削除
docker compose down --volumes

# 完全なクリーンアップ（コンテナ、ボリューム、ネットワーク、イメージ）
docker compose down --volumes --rmi all
```

### マルチルートワークスペースのサポート

このセットアップは、VS Codeのマルチルートワークスペース機能をサポートしており、親ディレクトリ内の複数プロジェクトを独立したワークスペースフォルダとして管理できます。

#### メリット
- 各プロジェクトフォルダが独立したワークスペースとして認識される
- プロジェクトごとに異なるPython/Node.jsバージョンを設定可能
- プロジェクト固有の設定（例: `.vscode/settings.json`）が独立して機能
- 複数プロジェクト間の移動が容易

#### ワークスペースファイルの生成

提供されているスクリプトを実行して、ワークスペースファイルを自動生成します：

```bash
./generate-workspace.sh
```

これにより、親ディレクトリ内のすべてのディレクトリ（隠しディレクトリを除く）がスキャンされ、以下のファイルが生成されます：
- `multi-project.code-workspace`（workspace-dockerディレクトリに配置）

生成されたファイルには、親ディレクトリ内で見つかったすべてのプロジェクトフォルダが含まれます。

#### マルチルートワークスペースの開き方

**コンテナから開く**
1. Dev Containers経由で単一フォルダとしてコンテナに接続
2. コマンドパレット（`Ctrl+Shift+P`）を開く
3. 「File: Open Workspace from File...」を選択
4. `/home/<username>/workspace/workspace-docker/multi-project.code-workspace` を選択

一度開けば、VS Codeの「最近使ったファイル」に表示されるので、次回から簡単にアクセスできます（ただし、devcontainerへの再接続は毎回必要です）。

```

#### プロジェクトごとのPythonバージョン設定

各プロジェクトフォルダに `.vscode/settings.json` を作成してPythonインタープリターを指定します。

**例1: 仮想環境を使用（推奨）**

まず、使用したいPythonバージョンで仮想環境を作成します：
```bash
cd /home/<username>/workspace/project-a
# uvを使用
uv venv --python 3.11

cd /home/<username>/workspace/project-b
# uvを使用
uv venv --python 3.12
```

次に、VS Codeでそれを使用するように設定します：

**project-a/.vscode/settings.json (Python 3.11の仮想環境)**
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**project-b/.vscode/settings.json (Python 3.12の仮想環境)**
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**例2: pyenvでインストールしたPythonを直接使用**

**project-a/.vscode/settings.json (pyenv Python 3.11)**
```json
{
  "python.defaultInterpreterPath": "~/.pyenv/versions/3.11.9/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

**例3: uvのPython選択機能を使用**

```json
{
  "python.defaultInterpreterPath": "python",
  "python.analysis.extraPaths": ["${workspaceFolder}"]
}
```

この設定では、VS Codeがプロジェクト用にuvで管理されているPythonバージョンを使用します。

## 開発の流れ

### Python開発の例

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

### Node.js開発の例

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

**Pythonパッケージ管理ツール** (カスタムモードで選択、デフォルト: ノーマルモードではuv):
- **uv**: 高速でオールインワンのPythonパッケージ・バージョン管理（Rust製、pip互換）
- **poetry**: モダンなPython依存関係管理・パッケージング
- **pyenv + poetry**: Pythonバージョン管理（pyenv）+ 依存関係管理（poetry）
- **mise**: 多言語対応バージョン管理ツール（Python、Node.js、Ruby等）

**Node.jsバージョン管理ツール** (カスタムモードで選択、デフォルト: ノーマルモードではVolta):
- **Volta**: プロジェクトベースで自動切り替えするNode.jsバージョン管理
- **nvm**: 伝統的で最も広く使われているNode.jsバージョン管理ツール
- **fnm**: Fast Node Manager（Rust製、nvmの高速代替）
- **mise**: 多言語対応バージョン管理ツール（Python、Node.js、Ruby等）

**その他のツール**:
- **Docker CLI**: コンテナ操作（ホストのDockerデーモンをソケット経由で利用）
- **AWS CLI v2**: AWSリソース管理
- **AWS SAM CLI**: サーバーレスLambda関数のローカルでのビルド、テスト、実行（カスタムモードではオプション / ノーマルモードではデフォルトでインストール）
- **Slack CLI**: Slackワークスペース連携とAPIテストのためのCLIツール（カスタムモードではオプション / ノーマルモードではデフォルトでインストール）
- **GitHub CLI**: リポジトリ管理、プルリクエスト、Issue、ワークフロー操作のためのGitHubコマンドラインインターフェース（カスタムモードではオプション / ノーマルモードではデフォルトでインストール）

### システムパッケージ（常時インストール）

以下のパッケージはノーマル・カスタム両モードで常にインストールされ、完全な開発環境を提供します。

#### 必須パッケージ
- **ca-certificates** - SSL/TLS証明書管理、安全なHTTPS接続に必要
- **gnupg** - データ暗号化・署名のためのGNU Privacy Guard
- **openssh-client** - セキュアなリモート接続のためのSSHクライアント

#### 開発ツール
- **git** - バージョン管理システム
- **make** - ビルド自動化ツール
- **build-essential** - C/C++コンパイラとビルドツール（gcc, g++, make, libc-dev）

#### エディタ
- **vim** - 強力なテキストエディタ
- **nano** - シンプルで使いやすいテキストエディタ

#### 圧縮・アーカイブツール
- **zip/unzip** - ZIPアーカイブユーティリティ
- **tar** - テープアーカイブユーティリティ
- **gzip** - GNU gzip圧縮
- **bzip2** - bzip2圧縮
- **xz-utils** - XZ圧縮フォーマット

#### ネットワーク・ダウンロードツール
- **curl** - コマンドラインHTTPクライアント
- **wget** - ネットワークダウンローダー
- **rsync** - 高速ファイル同期・転送

#### システムユーティリティ
- **sudo** - 別ユーザーとしてコマンド実行
- **tree** - ディレクトリ構造可視化
- **jq** - JSONプロセッサ
- **less** - ファイルページャ
- **bash-completion** - コマンド自動補完
- **procps** - プロセス監視ユーティリティ（ps, topなど）
- **iproute2** - 高度なネットワークユーティリティ（ipコマンド）

#### 開発ライブラリ
- **libssl-dev** - SSL/TLS開発ライブラリ
- **zlib1g-dev** - 圧縮ライブラリ
- **libbz2-dev** - bzip2ライブラリ
- **libreadline-dev** - コマンドライン編集用Readlineライブラリ
- **libsqlite3-dev** - SQLite3データベースライブラリ
- **libncursesw5-dev** - ターミナルUIライブラリ
- **tk-dev** - Tk GUIツールキット
- **libxml2-dev** - XML処理ライブラリ
- **libxmlsec1-dev** - XMLセキュリティライブラリ
- **libffi-dev** - 外部関数インターフェースライブラリ
- **liblzma-dev** - XZ圧縮ライブラリ

#### ロケールサポート
- **locales** - ロケール設定（多言語テキストのUTF-8サポート）

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
| `uv-python` | `~/.local/share/uv` | uv インストールPythonバージョン |
| `poetry-cache` | `~/.cache/pypoetry` | Poetry キャッシュ |
| `poetry-data` | `~/.local/share/pypoetry` | Poetry データ |
| `pyenv` | `~/.pyenv` | pyenv Pythonバージョン |
| `volta-tools` | `~/.volta/tools` | Volta ツール |
| `nvm` | `~/.nvm` | nvm Node.jsバージョン |
| `fnm` | `~/.local/share/fnm` | fnm Node.jsバージョン |
| `mise-data` | `~/.local/share/mise` | mise インストールツール |
| `mise-cache` | `~/.cache/mise` | mise キャッシュ |
| `npm-cache` | `~/.npm` | npm キャッシュ |
| `pnpm-cache` | `~/.cache/pnpm` | pnpm メタデータキャッシュ |
| `pnpm-store` | `~/.local/share/pnpm` | pnpm グローバルストア |
| `aws` | `~/.aws` | AWS CLI認証情報・設定 |
| `gh-config` | `~/.config/gh` | GitHub CLI設定と認証情報 |
| `bash-history` | `~/.docker_history` | bash 履歴 |

> **注意**: 選択したパッケージ管理ツールに関わらず、すべてのボリュームが作成されます。未使用のボリュームは空のままで、著しい容量を消費しません。

### 読み取り専用マウント

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `~/.gitconfig` | `~/.gitconfig` | Git 設定 |
| `~/.ssh` | `~/.ssh` | SSH キー（Git認証等に使用） |

> **カスタマイズ**: 特定のSSH鍵のみマウントしたい場合は、`docker-compose.yml`で個別に指定できます（例: `~/.ssh/id_ed25519:/home/${USERNAME}/.ssh/id_ed25519:ro`）

### Dev Container専用

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | ホストDocker接続 |

## 注意事項

### セキュリティ

- **Docker ソケット**: ホストのDockerソケットをマウントしているため、コンテナからホストのDocker環境を完全制御可能
- **個人設定**: `~/.gitconfig`、`~/.ssh` が読み取り専用でマウントされます。`~/.aws` はボリュームマウントで永続化されます
- **機密情報**: 生成された `.env`、`.envs/*.env` にはユーザー情報（UID/GID/Docker GID）が含まれます

> **注意**: `~/.ssh`ディレクトリ全体がコンテナ内からアクセス可能です。読み取り専用のため変更はできませんが、コンテナ内のプロセスから鍵ファイルを読み取ることは可能です。信頼できないコードを実行する場合は注意してください。

### ファイル管理

- **テンプレートファイル必須**: `*.template` ファイルが必要です
- **生成ファイル**: `Dockerfile`、`docker-compose.yml`、`.devcontainer/devcontainer.json`、`.devcontainer/docker-compose.yml`、`.env`、`.envs/` は Git 管理から除外を推奨（自動生成されます）
- **永続化データ**: Docker ボリュームのデータは `docker compose down --volumes` で削除されます
- **環境変数**: `.envs/<service_name>.env`でサービスごとに環境変数を管理。`.env`はシンボリックリンクで切り替え可能
- **シンボリックリンク**: `.env`は相対パスのシンボリックリンクです。プロジェクトルートから`docker compose`コマンドを実行してください

### 開発環境

- **Python**: 選択したパッケージ管理ツール（uv/poetry/pyenv/mise）で管理。poetry互換性のためシステムのpython3がインストールされます
- **Node.js**: 選択したバージョン管理ツール（Volta/nvm/fnm/mise）で管理
- **pnpm**: 高速パッケージマネージャ、グローバルストアとキャッシュが永続化
- **ポート**: デフォルトで 3000 番ポートがフォワードされます
- **パッケージ管理ツール**: 選択したツールのみインストールされます。すべてのボリュームマウントポイントは将来の使用のために作成されます

### 環境切り替え時の注意事項

プロジェクトには環境切り替えスクリプト（`switch-env.sh`）がありますが、**ユーザー名（USERNAME）を変更する場合は必ずコンテナの再ビルドが必要**です。

**環境切り替え手順:**

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

**理由:**
- Dockerイメージ内でユーザーが作成される際、ビルド時のUSERNAME引数が使用されます
- 環境変数を変更してもビルドキャッシュが残っている場合、古いユーザー名のままとなります
- `--no-cache` オプションでキャッシュを無視して完全に再ビルドする必要があります

### トラブルシューティング

- **権限エラー**: UID/GID が正しく設定されているか確認
- **Docker 接続エラー**: Docker GIDが自動検出されているか確認。`getent group docker | cut -d: -f3`コマンドでホストのDocker GIDを確認できます
- **ボリューム問題**: `docker volume ls` でボリューム状態を確認
- **ユーザー名が古いまま**: 上記の「環境切り替え時の注意事項」を参照してキャッシュなしで再ビルド

## よく使うコマンド集

### 環境のセットアップと切り替え

```bash
# 初回セットアップ
bash setup-docker.sh

# 環境の切り替え（対話式）
bash switch-env.sh

# 環境の切り替え（引数指定）
bash switch-env.sh dev
bash switch-env.sh prod

# 利用可能な環境の確認
ls -la .envs/
```

### Docker操作

```bash
# イメージのビルド
docker compose build
docker compose build --no-cache  # キャッシュなし

# コンテナの起動
docker compose up -d
docker compose up -d --build     # ビルドと同時に起動

# コンテナの停止・削除
docker compose down
docker compose down --volumes    # ボリュームも削除

# コンテナ内でシェルを起動
docker compose exec <サービス名> bash

# ログの確認
docker compose logs
docker compose logs -f           # リアルタイム表示

# コンテナの状態確認
docker compose ps

# リソースの使用状況確認
docker compose stats
```

### 完全な再構築

```bash
# 環境変更後の完全な再構築
docker compose down --volumes
docker compose build --no-cache
docker compose up -d
```

### テストと検証

```bash
# プロジェクトの整合性テスト
bash test.sh

# 生成ファイルの確認
cat .env
cat Dockerfile
cat docker-compose.yml
cat .devcontainer/devcontainer.json
cat .devcontainer/docker-compose.yml

# または一括確認
ls -la .env Dockerfile docker-compose.yml .devcontainer/
```

### クリーンアップ

```bash
# 生成ファイルの削除（手動）
rm -f Dockerfile docker-compose.yml .env
rm -rf .devcontainer/devcontainer.json .devcontainer/docker-compose.yml

# ボリュームの削除
docker compose down --volumes

# すべて削除（イメージも含む）
docker compose down --volumes --rmi all
```

## テスト

プロジェクトの整合性を検証するテストスクリプトが含まれています：

```bash
# テストの実行
bash test.sh
```

### テストスクリプトの検証項目

1. **テンプレートファイルの存在確認**
   - `Dockerfile.template`
   - `docker-compose.yml.template`
   - `.devcontainer/devcontainer.json.template`
   - `.devcontainer/docker-compose.yml.template`

2. **スクリプトファイルの実行権限確認**
   - `setup-docker.sh` が実行可能か
   - `switch-env.sh` が実行可能か

3. **`.envs` ディレクトリの確認**
   - `.envs/` ディレクトリが存在するか

4. **生成ファイルの確認**（セットアップ実行後の場合）
   - `Dockerfile`, `docker-compose.yml`, `.env` が存在するか
   - `.devcontainer/devcontainer.json`, `.devcontainer/docker-compose.yml` が存在するか
   - `.env` がシンボリックリンクであり、有効なファイルを指しているか
   - `.envs/` 内に環境変数ファイル（`*.env`）が存在するか

5. **Docker環境の前提条件確認**
   - Docker がインストールされているか
   - Docker Compose が利用可能か

テストはカラー出力で結果を表示し、失敗したテストがある場合は終了コード 1 を返します。セットアップが未実行の場合は警告を表示しますが、テストは失敗しません。

## プロジェクトファイル

- `setup-docker.sh` - ノーマル/カスタムモード選択機能付きセットアップスクリプト
- `switch-env.sh` - 環境切り替えスクリプト
- `test.sh` - テストスクリプト
- `Dockerfile.template` - ノーマルモード用Dockerfileテンプレート（Python & Node.js開発推奨ツール）
- `Dockerfile.custom.template` - カスタムモード用Dockerfileテンプレート（選択的インストール）
- `docker-compose.yml.template` - ノーマルモード用docker-compose.ymlテンプレート
- `docker-compose.custom.template` - カスタムモード用docker-compose.ymlテンプレート
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container設定のテンプレート
- `.devcontainer/docker-compose.yml.template` - Dev Container用docker-compose設定のテンプレート

## ドキュメント

- [英語版 README (English)](../README.md)
- [変更履歴](../CHANGELOG.md)

## ライセンス

このプロジェクトは[MIT License](../LICENSE)の下でライセンスされています。詳細は[LICENSE](../LICENSE)ファイルを参照してください。
