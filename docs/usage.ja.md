# 使い方ガイド

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

### ワークスペースファイルの生成

`generate-workspace.sh` を使って `.code-workspace` ファイルを対話的に作成・更新できます:

```bash
bash generate-workspace.sh
```

TUI（ターミナルUI）でフォルダを選択します:

1. 親ディレクトリ（`..`）配下のプロジェクトフォルダを**スキャン**
2. 矢印キーで移動、Enterで選択/解除、`a`で全選択、`d`で決定の**複数選択**リストを表示
3. `workspaces/` ディレクトリに `.code-workspace` ファイルを**出力**

**操作フロー:**

| 状況 | 動作 |
|------|------|
| 既存ファイルなし | フォルダ選択 → ファイル名入力 → 新規作成 |
| 既存ファイルあり | 「既存ファイルを更新」または「新規作成」を選択 |
| 更新時 | 現在のフォルダ構成が事前選択された状態で変更可能 |

**特徴:**
- サブディレクトリのみを含むディレクトリは自動展開（例: `group/repo1`, `group/repo2`）
- `config/workspace-settings.json` のVS Code設定を生成ファイルに埋め込み
- 同名ファイルが存在する場合は上書き確認

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
