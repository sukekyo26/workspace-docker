# workspace-docker

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。proto（多言語バージョンマネージャー）とプラグインベースのツール選択システムを備えています。

## 主な特徴

- **プラグインアーキテクチャ**: `plugins/*.toml`による拡張可能なツール選択 — TOMLファイルの編集でツールの追加・カスタマイズが可能
- **TOML設定ファイル**: すべての設定が`workspace.toml`に集約 — 編集して再実行するだけで再生成
- **proto**: Python、Node.js、Bun、Deno、Go、Rust、および100以上のツールに対応した統合的な多言語バージョンマネージャー
- **カスタムCA証明書**: 企業プロキシ/VPN環境向けのカスタムCA証明書の自動インストール
- **永続化対応**: protoツールや設定が永続化され、コンテナ再作成後も保持
- **ワークスペース統合**: 複数プロジェクトを一つの開発環境で管理
- **VS Code Dev Container対応**: `.devcontainer`設定により、VS Codeとシームレスに統合
- **ホストDocker活用**: コンテナ内からホストのDockerを安全に利用
- **自動環境検出**: UID/GID/Docker GIDを自動検出し、権限問題を回避
- **UTF-8ロケール**: 日本語を含む多言語テキストを正しく表示
- **品質保証**: 8つのテストスイートとGitHub Actions CI/CD（ShellCheck、Hadolint、スナップショットテスト）

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
- Dockerがホストマシンにインストールされていること

**オプション:**
- VS Code + Dev Containers 拡張機能

以下のホスト設定ファイルがコンテナ内にマウントされます：

- `~/.ssh/` - SSH鍵（ホストと同期）

#### Dockerのインストール（Ubuntu）

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

※ グループ変更反映のため再ログインが必要です。

### セットアップ手順

1. **セットアップスクリプトの実行（初回 — 対話モード）**
```bash
bash setup-docker.sh
```
コンテナサービス名、ユーザー名、プラグイン選択が求められます。
`workspace.toml`とすべてのDocker設定ファイルが生成されます。

2. **再設定（workspace.tomlを編集して再生成）**

   初回セットアップ後は、`workspace.toml`を編集してスクリプトを再実行するだけです：
   ```bash
   # 設定を編集
   vim workspace.toml

   # workspace.tomlからすべてのファイルを再生成
   bash setup-docker.sh
   ```

   対話式セットアップを再実行するには、`--init`フラグを使用：
   ```bash
   bash setup-docker.sh --init
   ```

3. **workspace.toml 設定**

   ```toml
   # workspace.toml — workspace-docker configuration
   # Edit this file and run setup-docker.sh to regenerate

   [container]
   service_name = "dev"
   username = "devuser"
   ubuntu_version = "24.04"

   [plugins]
   enable = ["aws-cli", "aws-sam-cli", "docker-cli", "github-cli"]

   [apt]
   extra_packages = ["ripgrep", "fd-find"]  # オプション

   [ports]
   forward = [3000]
   ```

   利用可能なプラグインは`plugins/*.toml`で定義されています。各プラグインはインストール手順を含む自己完結型のTOMLファイルです：
   - `aws-cli` — AWS CLI v2
   - `aws-sam-cli` — AWS SAM CLI
   - `docker-cli` — Docker CLI（ソケットマウント経由でホストDockerを利用）
   - `github-cli` — GitHub CLI
   - `zig` — Zigコンパイラ（cargo-lambdaのクロスコンパイル用）

4. **自動検出される情報**
   - **UID/GID**: 現在のユーザーのUID/GIDを自動検出
   - **Docker GID**: ホストのDocker グループGIDを自動検出（`/var/run/docker.sock`から取得）

5. **生成されるファイル**
   - `workspace.toml` - 設定ファイル（これを編集します）
   - `Dockerfile` - テンプレート + プラグインから生成
   - `docker-compose.yml` - テンプレートから生成
   - `.devcontainer/devcontainer.json` - VS Code Dev Container設定
   - `.devcontainer/docker-compose.yml` - Dev Container用docker-compose設定
   - `.env` - docker-compose用環境変数（workspace.tomlから自動生成）

### 環境変数ファイル（.env）

`.env`ファイルは`setup-docker.sh`を実行するたびに`workspace.toml`から自動生成されます。手動で編集しないでください。

#### .envファイルの内容例

```env
# Environment variables for docker-compose
# Auto-generated from workspace.toml — do not edit manually
# Regenerate with: ./setup-docker.sh

CONTAINER_SERVICE_NAME=dev
USERNAME=devuser
UID=1000
GID=1000
DOCKER_GID=989
UBUNTU_VERSION=24.04
FORWARD_PORT=3000
```

### カスタムCA証明書（企業プロキシ/VPN対応）

SSL/TLSインスペクション（企業プロキシ、VPN）を使用している環境では、curl、pip、npm、aptなどのツールで証明書検証エラーを回避するためにカスタムCA証明書をインストールする必要がある場合があります。

#### セットアップ

1. **証明書ファイルを配置** - `certs/`ディレクトリにPEM形式（`.crt`拡張子）で配置:
   ```bash
   # 企業/プロキシの証明書をコピー
   cp /path/to/corporate-proxy-ca.crt ./certs/
   cp /path/to/internal-ca.crt ./certs/
   ```

2. **セットアップを実行** - 証明書は自動的に検出されます:
   ```bash
   bash setup-docker.sh
   ```

3. **コンテナを再ビルド**:
   ```bash
   bash rebuild-container.sh
   ```

#### 証明書の要件

- **形式**: PEMエンコードされたX.509証明書
- **拡張子**: `.crt`のみ
- **内容**: `-----BEGIN CERTIFICATE-----`で始まり`-----END CERTIFICATE-----`で終わる必要があります
- **複数証明書**: サポート（すべての証明書がインストールされ、`/etc/ssl/certs/ca-certificates.crt`に統合されます）

#### 設定される環境変数

証明書がインストールされると、以下の環境変数が自動的に設定されます:

| 変数 | 使用するツール |
|------|---------------|
| `SSL_CERT_FILE` | OpenSSL、Python、その他多くのツール |
| `CURL_CA_BUNDLE` | curl |
| `REQUESTS_CA_BUNDLE` | Python requestsライブラリ |
| `NODE_EXTRA_CA_CERTS` | Node.js |

すべての変数はカスタム証明書を含む`/etc/ssl/certs/ca-certificates.crt`を参照します。

#### セキュリティに関する注意

`certs/`ディレクトリ内の証明書ファイル（`.crt`、`.pem`）は`.gitignore`でgitから除外されています。証明書をバージョン管理にコミットしないでください。

### 開発環境の起動方法

#### 方法1: VS Code Dev Container（推奨）

**単一プロジェクトの場合：**
1. VS Codeでこのフォルダを開く（WSL/SSH/EC2 ではリモート拡張経由で接続）
2. コマンドパレット（Ctrl+Shift+P）から「開発コンテナ: コンテナでフォルダーを開く」を実行
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

#### 方法2: Docker Compose（手動）

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

**例2: proto経由でインストールしたPythonを直接使用**

**project-a/.vscode/settings.json (proto Python 3.11)**
```json
{
  "python.defaultInterpreterPath": "~/.proto/tools/python/3.11.9/bin/python",
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

**プラグインツール**（`workspace.toml`で設定、`plugins/*.toml`で定義）:
- **Docker CLI** (`docker-cli`) — コンテナ操作（ホストのDockerデーモンをソケットマウント経由で利用）
- **AWS CLI v2** (`aws-cli`) — AWSリソース管理
- **AWS SAM CLI** (`aws-sam-cli`) — サーバーレスLambda関数のローカルでのビルド、テスト、実行
- **GitHub CLI** (`github-cli`) — リポジトリ管理、プルリクエスト、Issue、ワークフロー操作のためのCLI
- **Zig** (`zig`) — cargo-lambdaのクロスコンパイルに必要なZigコンパイラ（x86_64とaarch64をサポート）

各プラグインは`plugins/`ディレクトリ内の自己完結型TOMLファイルで、メタデータ、Dockerfile命令、バージョン情報を含みます。新しいツールを追加するには、`plugins/<name>.toml`ファイルを作成するだけです。

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
- **python3** - Python 3インタープリター（AIコーディングエージェントや汎用スクリプト用のシステムPython）
- **python3-pip** - Pythonパッケージインストーラ
- **python3-venv** - Python仮想環境サポート
- **file** - ファイル種別識別ユーティリティ
- **patch** - diff/patchファイル適用ツール
- **gettext-base** - テキスト処理ユーティリティ（envsubst）

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
- **dnsutils** - DNS診断ツール (dig, nslookup)
- **iputils-ping** - ネットワーク疎通確認 (ping)
- **net-tools** - ネットワーク設定ユーティリティ (ifconfig, netstat, route)

#### システムユーティリティ
- **sudo** - 別ユーザーとしてコマンド実行
- **tree** - ディレクトリ構造可視化
- **jq** - JSONプロセッサ
- **bc** - シェルスクリプト用の任意精度計算機
- **less** - ファイルページャ
- **bash-completion** - コマンド自動補完
- **procps** - プロセス監視ユーティリティ（ps, topなど）
- **iproute2** - 高度なネットワークユーティリティ（ipコマンド）
- **lsb-release** - Linux Standard Baseバージョン報告ユーティリティ
- **uuid-runtime** - UUID生成ユーティリティ（uuidgenコマンド）

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
- **カスタム設定** - `workspace-docker/config/.bashrc_custom` を通じたユーザー固有の設定（ホストから直接編集可能）

#### カスタム設定ファイルの使用方法

コンテナは `workspace-docker/config/.bashrc_custom` にカスタム設定ファイルをサポートしています。このファイルは：
- **シェル起動時に `.bashrc` から自動読み込み**
- **ホストから直接編集可能**（コンテナに入る必要がない）
- **ワークスペースの一部**で管理が簡単、バージョン管理も可能
- **Dockerfileの設定と分離**され、保守性が向上

**セットアップ：**

```bash
# サンプルファイルをコピー（ホストから）
cp config/.bashrc_custom.example config/.bashrc_custom

# ホストから直接編集（お気に入りのエディタを使用）
vim config/.bashrc_custom  # または code、nano など
```

**設定例：**

```bash
# カスタムエイリアス
alias ll="ls -lah"
alias gs="git status"

# 環境変数
export MY_CUSTOM_VAR=value

# ツール固有の設定
# 例：Rust/Cargo環境（proto経由でインストールした場合）
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
```

**変更を適用：**
```bash
# コンテナ内から
source ~/.bashrc
```

**メリット：**
- コンテナに入らずホストから編集可能
- 見つけやすく管理しやすい（workspace-docker/config/内）
- バージョン管理可能（必要に応じてgitに追加）
- コンテナ再起動時に設定が自動適用
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
| `cargo` | `~/.cargo` | Rust/Cargoツールとパッケージ |
| `rustup` | `~/.rustup` | Rustツールチェーン管理 |
| `deno` | `~/.deno` | Denoランタイムとキャッシュモジュール |
| `bun` | `~/.bun` | Bunランタイムとパッケージ |
| `go` | `~/go` | Goワークスペース（GOPATH） |
| `local` | `~/.local` | ユーザーインストールパッケージ（pipx、uv等）、bash履歴 |

### ホスト同期マウント

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `~/.ssh` | `~/.ssh` | SSH キー（Git認証等に使用） |

> **注記**: これらのファイルはホストと同期されており、コンテナ内での変更がホストに永続化され、その逆も同様です。
>
> **カスタマイズ**: 特定のSSH鍵のみマウントしたい場合は、`docker-compose.yml`で個別に指定できます（例: `~/.ssh/id_ed25519:/home/${USERNAME}/.ssh/id_ed25519`）

### Dev Container専用

| ホスト | コンテナ内 | 用途 |
|--------|------------|------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | ホストDocker接続 |

## 注意事項

### セキュリティ

- **Docker ソケット**: ホストのDockerソケットをマウントしているため、コンテナからホストのDocker環境を完全制御可能
- **個人設定**: `~/.ssh`が開発の利便性のためホストと同期されます。`~/.aws` はボリュームマウントで永続化されます
- **機密情報**: 生成された `.env` にはユーザー情報（UID/GID/Docker GID）が含まれます

> **注意**: `~/.ssh`ディレクトリ全体がコンテナ内からアクセス可能です。コンテナ内のプロセスはこれらのファイルを読み取りおよび変更できます。信頼できないコードを実行する場合は注意してください。

### ファイル管理

- **テンプレートファイル必須**: `*.template` ファイルが必要です
- **生成ファイル**: `Dockerfile`、`docker-compose.yml`、`.devcontainer/devcontainer.json`、`.devcontainer/docker-compose.yml`、`.env` は自動生成 — Git管理から除外推奨
- **設定**: `workspace.toml`が唯一の設定ファイル — これを編集して`setup-docker.sh`を再実行
- **永続化データ**: Docker ボリュームのデータは `docker compose down --volumes` で削除されます

### 開発環境

- **proto**: Python、Node.js、および100以上のツールを管理する統合バージョンマネージャー
- **プラグインツール**: `workspace.toml`で設定、`plugins/*.toml`で定義
- **ポート**: `workspace.toml`で設定可能（デフォルト: 3000）

### 再設定時の注意事項

設定を変更するには、`workspace.toml`を編集して`setup-docker.sh`を実行します。ただし、**ユーザー名（USERNAME）を変更する場合は必ずコンテナの再ビルドが必要**です。

**再設定手順:**

1. **設定を編集して再生成**
```bash
vim workspace.toml
bash setup-docker.sh
```

2. **ユーザー名が変更された場合の必須手順**
```bash
# コンテナを停止・削除
docker compose down

# キャッシュなしで再ビルド（重要！）
bash rebuild-container.sh
```

**理由:**
- Dockerイメージ内でユーザーが作成される際、ビルド時のUSERNAME引数が使用されます
- ユーザー名を変更してもビルドキャッシュが残っている場合、古いユーザー名のままとなります
- `rebuild-container.sh`でキャッシュを無視して完全に再ビルドする必要があります

### トラブルシューティング

- **権限エラー**: UID/GID が正しく設定されているか確認
- **Docker 接続エラー**: Docker GIDが自動検出されているか確認。`getent group docker | cut -d: -f3`コマンドでホストのDocker GIDを確認できます
- **ボリューム問題**: `docker volume ls` でボリューム状態を確認
- **ユーザー名が古いまま**: 上記の「再設定時の注意事項」を参照してキャッシュなしで再ビルド

## よく使うコマンド集

### セットアップと再設定

```bash
# 初回セットアップ（対話式）
bash setup-docker.sh

# 再設定: workspace.tomlを編集して再生成
bash setup-docker.sh

# 対話式セットアップを再実行
bash setup-docker.sh --init
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

`rebuild-container.sh` を使用（推奨）:

```bash
bash rebuild-container.sh
```

このスクリプトは `devcontainer up --build-no-cache --remove-existing-container` を実行し、
devcontainer.json の Features、VS Code 拡張機能設定、Docker イメージのリビルドを一括で行います。

または Docker Compose で手動実行:

```bash
docker compose down --volumes
docker compose build --no-cache
docker compose up -d
```

### テストと検証

```bash
# 全テストスイートを実行（8スイート）
bash tests/run_all.sh

# 生成ファイルの確認
cat workspace.toml
cat .env
cat Dockerfile
cat docker-compose.yml
cat .devcontainer/devcontainer.json
cat .devcontainer/docker-compose.yml
```

### クリーンアップ

```bash
# 生成ファイルの削除（workspace.tomlは再設定用に保持）
rm -f Dockerfile docker-compose.yml .env
rm -f .devcontainer/devcontainer.json .devcontainer/docker-compose.yml

# ボリュームの削除
docker compose down --volumes

# すべて削除（イメージも含む）
docker compose down --volumes --rmi all
```

## テスト

プロジェクトには8つのテストスイートを含む包括的なテスト環境が整備されています：

```bash
# 全テストの実行
bash tests/run_all.sh
```

### テストスイート

| スイート | 説明 |
|----------|------|
| `test_project_structure` | テンプレート存在確認、スクリプト権限、全`.sh`ファイルのShellCheck |
| `test_lib` | ライブラリ関数のユニットテスト（TOMLパーサー、バリデータ、ジェネレータ、devcontainer） |
| `test_plugins` | プラグインTOML構造検証（メタデータ、インストールセクション、バージョン） |
| `test_setup_docker` | `setup-docker.sh`の実行ベーステスト（workspace.tomlからの再生成） |
| `test_rebuild_container` | コンテナ検出とdevcontainer CLIラッパーのテスト |
| `test_generate_workspace` | マルチルートワークスペースファイル生成テスト |
| `test_integration` | エンドツーエンド生成と構造的妥当性テスト（Dockerfile, YAML, JSON） |
| `test_snapshot` | 生成ファイルのスナップショット回帰テスト |

## プロジェクトファイル

### コアスクリプト
- `setup-docker.sh` - セットアップスクリプト（対話式または`workspace.toml`から再生成）
- `rebuild-container.sh` - devcontainer CLIを使用したキャッシュなしリビルドスクリプト
- `generate-workspace.sh` - マルチルートワークスペース生成スクリプト

### 設定
- `workspace.toml` - ユーザー設定（コンテナ名、ユーザー名、プラグイン、ポート）

### プラグイン（`plugins/`）
- `plugins/aws-cli.toml` - AWS CLI v2プラグイン
- `plugins/aws-sam-cli.toml` - AWS SAM CLIプラグイン
- `plugins/docker-cli.toml` - Docker CLIプラグイン
- `plugins/github-cli.toml` - GitHub CLIプラグイン
- `plugins/zig.toml` - Zigコンパイラプラグイン

各プラグインTOMLには`[metadata]`（名前、説明、デフォルト）、`[install]`（Dockerfile命令）、`[version]`（ピン留めまたはlatest）が含まれます。

### テンプレート
- `Dockerfile.template` - プレースホルダー付きDockerfileテンプレート
- `docker-compose.yml.template` - docker-compose.ymlテンプレート
- `.devcontainer/devcontainer.json.template` - VS Code Dev Container設定のテンプレート
- `.devcontainer/docker-compose.yml.template` - Dev Container用docker-compose設定のテンプレート

### ライブラリ（`lib/`）
- `lib/generators.sh` - テンプレート生成関数
- `lib/plugin.sh` - プラグイン読み込みとDockerfileスニペット生成
- `lib/toml_parser.py` - TOMLパーサー（Python 3.11+ tomllib）
- `lib/validators.sh` - 入力検証ライブラリ（サービス名、ユーザー名）
- `lib/errors.sh` - エラーハンドリングとメッセージングライブラリ
- `lib/devcontainer.sh` - devcontainer CLIの前提条件チェックとWSL対応ラッパー

### テスト（`tests/`）
- `tests/run_all.sh` - 全8スイートのテストランナー
- `tests/test_helper.sh` - 共有アサーション関数
- `tests/test_*.sh` - 個別テストスイート

### CI/CD
- `.github/workflows/ci.yml` - GitHub Actionsワークフロー
  - ShellCheck静的解析
  - 8テストスイート実行
  - テンプレート検証（YAML/JSON）
  - HadolintによるDockerfile Lint
  - Dockerビルド検証

## ドキュメント

- [英語版 README (English)](../README.md)
- [変更履歴](../CHANGELOG.md)

## ライセンス

このプロジェクトは[MIT License](../LICENSE)の下でライセンスされています。詳細は[LICENSE](../LICENSE)ファイルを参照してください。
