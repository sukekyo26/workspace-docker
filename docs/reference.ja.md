# リファレンス

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

## システムパッケージ（常時インストール）

以下のパッケージは常にインストールされ、完全な開発環境を提供します。

### 必須パッケージ
- **ca-certificates** - SSL/TLS証明書管理、安全なHTTPS接続に必要
- **gnupg** - データ暗号化・署名のためのGNU Privacy Guard
- **openssh-client** - セキュアなリモート接続のためのSSHクライアント

### 開発ツール
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

### エディタ
- **vim** - 強力なテキストエディタ
- **nano** - シンプルで使いやすいテキストエディタ

### 圧縮・アーカイブツール
- **zip/unzip** - ZIPアーカイブユーティリティ
- **tar** - テープアーカイブユーティリティ
- **gzip** - GNU gzip圧縮
- **bzip2** - bzip2圧縮
- **xz-utils** - XZ圧縮フォーマット

### ネットワーク・ダウンロードツール
- **curl** - コマンドラインHTTPクライアント
- **wget** - ネットワークダウンローダー
- **rsync** - 高速ファイル同期・転送
- **dnsutils** - DNS診断ツール (dig, nslookup)
- **iputils-ping** - ネットワーク疎通確認 (ping)
- **net-tools** - ネットワーク設定ユーティリティ (ifconfig, netstat, route)

### システムユーティリティ
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

### 開発ライブラリ
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

### ロケールサポート
- **locales** - ロケール設定（多言語テキストのUTF-8サポート）

## ロケール設定

- **デフォルトロケール**: `en_US.UTF-8`
- 日本語テキストが正しく表示されるよう自動設定
- Git操作時の日本語ファイル名や差分も正常に表示

## シェル機能

- **Bash補完** - コマンドの自動補完
- **Git統合プロンプト** - ブランチ・状態表示
- **永続化履歴** - コマンド履歴の永続保存
- **カスタム設定** - `workspace-docker/config/.bashrc_custom` を通じたユーザー固有の設定（ホストから直接編集可能）

### カスタム設定ファイルの使用方法

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
