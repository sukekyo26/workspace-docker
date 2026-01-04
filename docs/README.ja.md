# workspace-docker

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。proto（多言語バージョンマネージャー）とモダンな開発ツールがプリインストールされています。

## 主な特徴

- **柔軟なセットアップ**: protoは常にインストールされ、他のツールは選択可能
- **proto**: Python、Node.js、Bun、Deno、Go、Rust、および100以上のツールに対応した統合的な多言語バージョンマネージャー
- **モダンな開発ツール**: Docker CLI、AWS CLI v2、AWS SAM CLI、GitHub CLI
- **永続化対応**: protoツールや設定が永続化され、コンテナ再作成後も保持
- **ワークスペース統合**: 複数プロジェクトを一つの開発環境で管理
- **VS Code Dev Container対応**: `.devcontainer`設定により、VS Codeとシームレスに統合
- **ホストDocker活用**: コンテナ内からホストのDockerを安全に利用
- **自動環境検出**: UID/GID/Docker GIDを自動検出し、権限問題を回避
- **UTF-8ロケール**: 日本語を含む多言語テキストを正しく表示
- **品質保証**: 組み込みの検証ライブラリと包括的なテストスイート、GitHub Actions CI/CD

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

3. **ソフトウェアの選択**
   - **proto**: 常にインストール（多言語バージョンマネージャー）
   - **Docker CLI**: コンテナ操作（デフォルト: Yes）
   - **AWS CLI v2**: AWSリソース管理（デフォルト: Yes）
   - **AWS SAM CLI**: サーバーレスLambda関数のローカルでのビルド、テスト、実行（デフォルト: Yes）
   - **GitHub CLI**: リポジトリ管理、プルリクエスト、Issueおよびワークフロー操作のためのCLI（デフォルト: Yes）

4. **自動検出される情報**
   - **UID/GID**: 現在のユーザーのUID/GIDを自動検出
   - **Docker GID**: ホストのDocker グループGIDを自動検出（`/var/run/docker.sock`から取得）

5. **生成されるファイル**
   - `Dockerfile` - テンプレートから生成
   - `docker-compose.yml` - テンプレートから生成
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

```env
# Environment variables for dev
# Generated on Fri Nov  8 12:34:56 UTC 2025

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
INSTALL_DOCKER=true
INSTALL_AWS_CLI=true
INSTALL_AWS_SAM_CLI=true
INSTALL_GITHUB_CLI=true
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
# proto経由でPythonとuvをインストール
proto install python 3.13
proto install uv

# プロジェクト作成
uv init my-python-project
cd my-python-project

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
# proto経由でNode.jsとpnpmをインストール
proto install node 22
proto install pnpm

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

### protoでその他の言語を使う

```bash
# その他のランタイムをインストール
proto install bun
proto install deno
proto install go
proto install rust

# インストール済みツールの一覧
proto list

# プロジェクト用にツールバージョンを固定（.prototoolsファイルを作成）
proto pin node 22
proto pin python 3.13
```

## プリインストールアプリケーション

### 開発ツール

**proto**（常にインストール）:
- **proto**: 統合的な多言語バージョンマネージャー。以下をサポート:
  - **Python**（+ poetry、uv）
  - **Node.js**（+ npm、pnpm、yarn）
  - **Bun**、**Deno**、**Go**、**Rust**、**Ruby**
  - プラグイン経由で100以上のサードパーティツール
  - `.prototools`ファイルによるプロジェクトベースのバージョン切り替え

**オプションツール**（セットアップ時に選択可能、デフォルトですべてインストール）:
- **Docker CLI**: コンテナ操作（ホストのDockerデーモンをソケットマウント経由で利用）
- **AWS CLI v2**: AWSリソース管理
- **AWS SAM CLI**: サーバーレスLambda関数のローカルでのビルド、テスト、実行
- **GitHub CLI**: リポジトリ管理、プルリクエスト、Issue、ワークフロー操作のためのGitHubコマンドラインインターフェース

### システムパッケージ（常時インストール）

以下のパッケージは常にインストールされ、完全な開発環境を提供します。

#### 必須パッケージ
- **ca-certificates** - SSL/TLS証明書管理、安全なHTTPS接続に必要
- **gnupg** - データ暗号化・署名のためのGNU Privacy Guard
- **openssh-client** - セキュアなリモート接続のためのSSHクライアント

#### 開発ツール
- **git** - バージョン管理システム
- **make** - ビルド自動化ツール
- **build-essential** - C/C++コンパイラとビルドツール（gcc, g++, make, libc-dev）
- **shellcheck** - シェルスクリプト静的解析ツール

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
- **lsb-release** - Linux Standard Baseバージョン報告ユーティリティ

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
- **カスタム設定** - `~/.local/.bashrc_custom` を通じたユーザー固有の設定（コンテナ再ビルド後も保持）

#### カスタム設定ファイルの使用方法

コンテナは `~/.local/.bashrc_custom` に永続的なカスタム設定ファイルをサポートしています。このファイルは：
- **シェル起動時に `.bashrc` から自動読み込み**
- **`local` ボリュームを通じてコンテナ再ビルド後も永続化**
- **Dockerfileの設定と分離**され、保守性が向上

**使用例：**

```bash
# カスタムエイリアスを追加
echo 'alias ll="ls -lah"' >> ~/.local/.bashrc_custom
echo 'alias gs="git status"' >> ~/.local/.bashrc_custom

# 環境変数を追加
echo 'export MY_CUSTOM_VAR=value' >> ~/.local/.bashrc_custom

# ツール固有の設定を追加
# 例：Rust/Cargo環境（proto経由でインストールした場合）
echo '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"' >> ~/.local/.bashrc_custom

# 変更を適用
source ~/.bashrc
```

**メリット：**
- カスタム設定がコンテナ再ビルド後も保持される
- Dockerfileはシステム全体のデフォルトを管理
- 環境間で共通の設定を簡単に共有
- Dockerfileの更新との競合がない

## マウントされているフォルダ

### ワークスペース

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `..` (親ディレクトリ) | `/home/<username>/workspace` | 開発プロジェクト群 |

### 永続化ボリューム

| ボリューム名 | マウント先 | 用途 |
|--------------|------------|------|
| `proto` | `~/.proto` | protoインストール済みツールとバージョン |
| `aws` | `~/.aws` | AWS CLI認証情報・設定 |
| `gh-config` | `~/.config/gh` | GitHub CLI設定と認証情報 |
| `bash-history` | `~/.docker_history` | bash 履歴 |
| `cargo` | `~/.cargo` | Rust/Cargoツールとパッケージ |
| `rustup` | `~/.rustup` | Rustツールチェーン管理 |
| `local` | `~/.local` | ユーザーインストールパッケージ（pipx、uv等）とカスタム設定（`.bashrc_custom`） |

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

### コアスクリプト
- `setup-docker.sh` - ツール選択機能付きセットアップスクリプト
- `switch-env.sh` - 環境切り替えスクリプト
- `test.sh` - 包括的なテストスクリプト
- `generate-workspace.sh` - マルチルートワークスペース生成スクリプト

### テンプレート
- `Dockerfile.template` - プレースホルダー付きDockerfileテンプレート
- `docker-compose.yml.template` - docker-compose.ymlテンプレート
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container設定のテンプレート
- `.devcontainer/docker-compose.yml.template` - Dev Container用docker-compose設定のテンプレート

### ライブラリ（`lib/`）
- `lib/versions.conf` - 一元化されたバージョン設定
- `lib/generators.sh` - 共有テンプレート生成関数
- `lib/validators.sh` - 入力検証ライブラリ（サービス名、ユーザー名、真偽値）
- `lib/errors.sh` - エラーハンドリングとメッセージングライブラリ

### CI/CD
- `.github/workflows/ci.yml` - 自動テストと検証のためのGitHub Actionsワークフロー
  - ShellCheck静的解析
  - 22項目のテストスイート実行
  - テンプレート検証（YAML/JSON）
  - HadolintによるDockerfile Lint
  - Dockerビルド検証

## ドキュメント

- [英語版 README (English)](../README.md)
- [変更履歴](../CHANGELOG.md)

## ライセンス

このプロジェクトは[MIT License](../LICENSE)の下でライセンスされています。詳細は[LICENSE](../LICENSE)ファイルを参照してください。
