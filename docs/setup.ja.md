# セットアップガイド

## 前提条件

**必須要件:**
- Dockerがホストマシンにインストールされていること

**オプション:**
- VS Code + Dev Containers 拡張機能

以下のホスト設定ファイルがコンテナ内にマウントされます：

- `~/.ssh/` - SSH鍵（ホストと同期）

### Dockerのインストール（Ubuntu）

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

※ グループ変更反映のため再ログインが必要です。

## セットアップ

1. **セットアップスクリプトの実行（初回 — 対話モード）**
   ```bash
   bash setup-docker.sh
   ```
   コンテナサービス名、ユーザー名、プラグイン選択が求められます。
   `workspace.toml`とすべてのDocker設定ファイルが生成されます。

2. **再設定（workspace.tomlを編集して再生成）**

   初回セットアップ後は、`workspace.toml`を編集してスクリプトを再実行するだけです：
   ```bash
   vim workspace.toml
   bash setup-docker.sh
   ```

   対話式セットアップを再実行するには、`--init`フラグを使用：
   ```bash
   bash setup-docker.sh --init
   ```

## workspace.toml 設定

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

## 自動検出される情報

- **UID/GID**: 現在のユーザーのUID/GIDを自動検出
- **Docker GID**: ホストのDocker グループGIDを自動検出（`/var/run/docker.sock`から取得）

## 生成されるファイル

- `workspace.toml` - 設定ファイル（これを編集します）
- `Dockerfile` - テンプレート + プラグインから生成
- `docker-compose.yml` - テンプレートから生成
- `.devcontainer/devcontainer.json` - VS Code Dev Container設定
- `.devcontainer/docker-compose.yml` - Dev Container用docker-compose設定
- `.env` - docker-compose用環境変数（workspace.tomlから自動生成）

## 環境変数ファイル（.env）

`.env`ファイルは`setup-docker.sh`を実行するたびに`workspace.toml`から自動生成されます。手動で編集しないでください。

### .envファイルの内容例

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

## カスタムCA証明書（企業プロキシ/VPN対応）

SSL/TLSインスペクション（企業プロキシ、VPN）を使用している環境では、curl、pip、npm、aptなどのツールで証明書検証エラーを回避するためにカスタムCA証明書をインストールする必要がある場合があります。

### セットアップ

1. **証明書ファイルを配置** - `certs/`ディレクトリにPEM形式（`.crt`拡張子）で配置:
   ```bash
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

### 証明書の要件

- **形式**: PEMエンコードされたX.509証明書
- **拡張子**: `.crt`のみ
- **内容**: `-----BEGIN CERTIFICATE-----`で始まり`-----END CERTIFICATE-----`で終わる必要があります
- **複数証明書**: サポート（すべての証明書がインストールされ、`/etc/ssl/certs/ca-certificates.crt`に統合されます）

### 設定される環境変数

証明書がインストールされると、以下の環境変数が自動的に設定されます:

| 変数 | 使用するツール |
|------|---------------|
| `SSL_CERT_FILE` | OpenSSL、Python、その他多くのツール |
| `CURL_CA_BUNDLE` | curl |
| `REQUESTS_CA_BUNDLE` | Python requestsライブラリ |
| `NODE_EXTRA_CA_CERTS` | Node.js |

すべての変数はカスタム証明書を含む`/etc/ssl/certs/ca-certificates.crt`を参照します。

### セキュリティに関する注意

`certs/`ディレクトリ内の証明書ファイル（`.crt`、`.pem`）は`.gitignore`でgitから除外されています。証明書をバージョン管理にコミットしないでください。

## 開発環境の起動方法

### 方法1: VS Code Dev Container（推奨）

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

詳細は下記の[マルチルートワークスペースのサポート](#マルチルートワークスペースのサポート)セクションを参照してください。

### 方法2: Docker Compose（手動）

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

## マルチルートワークスペースのサポート

このセットアップは、VS Codeのマルチルートワークスペース機能をサポートしており、親ディレクトリ内の複数プロジェクトを独立したワークスペースフォルダとして管理できます。

### メリット
- 各プロジェクトフォルダが独立したワークスペースとして認識される
- プロジェクトごとに異なるPython/Node.jsバージョンを設定可能
- プロジェクト固有の設定（例: `.vscode/settings.json`）が独立して機能
- 複数プロジェクト間の移動が容易

### ワークスペースファイルの生成

提供されているスクリプトを実行して、ワークスペースファイルを自動生成します：

```bash
./generate-workspace.sh
```

これにより、親ディレクトリ内のすべてのディレクトリ（隠しディレクトリを除く）がスキャンされ、以下のファイルが生成されます：
- `multi-project.code-workspace`（workspace-dockerディレクトリに配置）

### マルチルートワークスペースの開き方

**コンテナから開く**
1. Dev Containers経由で単一フォルダとしてコンテナに接続
2. コマンドパレット（`Ctrl+Shift+P`）を開く
3. 「File: Open Workspace from File...」を選択
4. `/home/<username>/workspace/workspace-docker/multi-project.code-workspace` を選択

一度開けば、VS Codeの「最近使ったファイル」に表示されるので、次回から簡単にアクセスできます（ただし、devcontainerへの再接続は毎回必要です）。

### プロジェクトごとのPythonバージョン設定

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

## 再設定時の注意事項

設定を変更するには、`workspace.toml`を編集して`setup-docker.sh`を実行します。ただし、**ユーザー名（USERNAME）を変更する場合は必ずコンテナの再ビルドが必要**です。

### 再設定手順

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

## トラブルシューティング

- **権限エラー**: UID/GID が正しく設定されているか確認
- **Docker 接続エラー**: Docker GIDが自動検出されているか確認。`getent group docker | cut -d: -f3`コマンドでホストのDocker GIDを確認できます
- **ボリューム問題**: `docker volume ls` でボリューム状態を確認
- **ユーザー名が古いまま**: 上記の「再設定時の注意事項」を参照してキャッシュなしで再ビルド
