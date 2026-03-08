# リファレンス

## プリインストールアプリケーション

### 開発ツール

**プラグインツール**（`workspace.toml`で設定、`plugins/*.toml`で定義）:
- **Docker CLI** (`docker-cli`, デフォルト: on) — コンテナ操作（ホストのDockerデーモンをソケットマウント経由で利用）
- **proto** (`proto`) — 統合的な多言語バージョンマネージャー（Python, Node.js, Bun, Deno, Go, Rust, 100以上のツール）
- **AWS CLI v2** (`aws-cli`) — AWSリソース管理
- **AWS SAM CLI** (`aws-sam-cli`) — サーバーレスLambda関数のローカルでのビルド、テスト、実行
- **GitHub CLI** (`github-cli`) — リポジトリ管理、プルリクエスト、Issue、ワークフロー操作のためのCLI
- **GitHub Copilot CLI** (`copilot-cli`) — AIパワードのコマンドラインアシスタント
- **Claude Code** (`claude-code`) — AnthropicのAIコーディングアシスタント
- **uv** (`uv`) — Astral製の高速Pythonパッケージ・プロジェクトマネージャー
- **Go** (`go`) — Go言語（チェックサム検証・GOPATHボリューム付き）
- **Rust** (`rust`) — rustupによるRustツールチェーン（cargo, clippy, rustfmt）と永続ボリューム
- **Zig** (`zig`) — cargo-lambdaのクロスコンパイルに必要なZigコンパイラ（x86_64とaarch64をサポート）
- **lazygit** (`lazygit`) — Git操作用ターミナルUI（チェックサム検証付き）
- **Starship** (`starship`) — 豊富なカスタマイズが可能なクロスシェルプロンプト（`custom-ps1` と競合）
- **Custom PS1** (`custom-ps1`) — 軽量なbashプロンプト。コンテナ名、gitステータス、カラー表示に対応（`starship` と競合）

各プラグインは`plugins/`ディレクトリ内の自己完結型TOMLファイルで、メタデータ、Dockerfile命令、バージョン情報を含みます。新しいツールを追加するには、`plugins/<name>.toml`ファイルを作成するだけです。

## プラグインの作成方法

新しいツールを追加するには、以下の構造で `plugins/<name>.toml` を作成します。

### TOML スキーマ

```toml
[metadata]
name = "My Tool"                  # 表示名
description = "ツールの説明"
default = false                   # true = デフォルトで有効
conflicts = ["other-plugin"]      # オプション: 排他的プラグイン

[apt]
packages = ["libfoo-dev"]         # オプション: apt依存パッケージ

[install]
requires_root = false             # true = root権限で実行（USER切替は自動）
user_dirs = ["/home/${USERNAME}/.tool"]  # オプション: ユーザー所有で作成するディレクトリ
volumes = ["/home/${USERNAME}/.tool"]    # オプション: 永続ボリュームマウント（名前はパスから自動導出）
dockerfile = '''
# ツールをインストールするDockerfile RUN命令
RUN curl -fsSL https://example.com/install.sh | sh
'''

[version]
strategy = "latest"               # "latest" または "pin"
pin = ""                          # strategy = "pin" 時のバージョン文字列
```

### 重要なルール

- **`requires_root`**: `true` の場合、ジェネレータが自動的に `USER root` / `USER ${USERNAME}` でラップします。手動で `USER` ディレクティブを含めないでください — 両方が存在する場合は検証警告が出力されます。
- **`user_dirs`**: インストール前にユーザー所有で存在する必要があるディレクトリ。有効な全プラグインのディレクトリがマージされ、プラグインインストール前に `USER root` ブロックで一括作成されます。中間の親ディレクトリは自動的に含まれます。
- **`${USERNAME}`**: ボリュームパスやdockerfile命令でこの変数を使用します。ビルド時に `workspace.toml` の値で置換されます。
- **`[apt].packages`**: プラグインが有効な場合のみインストールされます。ベースパッケージリスト（`config/apt-base-packages.conf`）との重複は自動検知されます。
- **`volumes`**（`[install]` 内）: `/home/${USERNAME}/` 配下の絶対パスの配列。ボリューム名はパスの basename から自動導出されます（先頭ドット除去、例: `/home/${USERNAME}/.aws` → `aws`）。マウント先ディレクトリはDockerfile内でユーザー権限で作成されます。
- **`dockerfile`**: トリプルクォート文字列（`'''...'''`）を使用します。各命令は後始末を行ってください（`apt-get clean`、`rm -rf /tmp/*`）。
- **`conflicts`**: 同時に有効化できないプラグインIDのリスト。競合する2つのプラグインが `[plugins].enable` に含まれている場合、ジェネレータはエラー終了します。ドキュメントの明瞭性のため競合関係の両方で宣言することを推奨しますが、片方の宣言だけでも検出は機能します。

### プラグインの競合

一部のプラグインは排他的であり、両方を有効化すると問題が発生します（例: PS1の二重設定）。`[metadata]` の `conflicts` フィールドでこれらの関係を宣言します。

| プラグイン | 競合先 | 理由 |
|:----------|:-------|:-----|
| `starship` | `custom-ps1` | 両方が `~/.bashrc` にPS1設定を書き込む。Starshipはプロンプトを完全制御し、custom-ps1は静的なPS1文字列を設定する。 |

**選択基準：**
- **Starship** — 多機能なクロスシェルプロンプト。git統合、実行時間表示、言語バージョン表示、`starship.toml` による豊富なテーマ設定が可能
- **Custom PS1** — 軽量、依存なしのbashプロンプト。コンテナ名、gitブランチ/ステータス、カラー表示に対応

### 例: 最小構成のプラグイン

```toml
[metadata]
name = "ripgrep"
description = "高速な再帰的grep"

[install]
requires_root = true
dockerfile = '''
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
'''

[version]
strategy = "latest"
```

## システムパッケージ

ベースパッケージは`config/apt-base-packages.conf`で管理されています。プロジェクト固有のパッケージは`workspace.toml`の`[apt] packages`で追加できます。

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
- **カスタム設定** - `config/.bashrc_custom` を通じたユーザー固有の設定（ホストから直接編集可能）

### カスタム設定ファイルの使用方法

コンテナは `config/.bashrc_custom` にカスタム設定ファイルをサポートしています。このファイルは：
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

## VS Code 拡張機能

VS Code の拡張機能は `workspace.toml` の `[vscode]` セクションで設定します。これらの拡張機能は Dev Container 作成時に自動インストールされます。

```toml
[vscode]
extensions = [
    "MS-CEINTL.vscode-language-pack-ja",
    "ms-azuretools.vscode-docker",
    "ms-python.python",
    "eamodio.gitlens",
    "github.copilot-chat",
]
```

各拡張機能はマーケットプレイス ID（`publisher.extension-name`）で指定します。リストは生成時に `devcontainer.json` の `customizations.vscode.extensions` に書き込まれます。

拡張機能 ID の確認方法: VS Code の拡張機能パネルを開く → 拡張機能を右クリック →「拡張機能 ID のコピー」。

## ワークスペース設定

`config/workspace-settings.json.example` は `generate-workspace.sh` で生成される `.code-workspace` ファイルに埋め込まれるデフォルトのVS Codeエディタ設定を定義します。

カスタマイズするには `config/workspace-settings.json.example` を `config/workspace-settings.json` にコピーして編集してください。ジェネレーターは `workspace-settings.json` があればそちらを使用し、なければ `.example` にフォールバックします。

**デフォルト設定:**

| 設定 | 値 | 説明 |
|------|-----|------|
| `files.autoSave` | `afterDelay` | 一定時間後に自動保存 |
| `files.trimTrailingWhitespace` | `true` | 保存時に末尾の空白を削除 |
| `files.insertFinalNewline` | `true` | ファイル末尾に改行を保証 |
| `editor.formatOnSave` | `true` | 保存時にフォーマット |
| `editor.insertSpaces` | `true` | タブの代わりにスペースを使用 |
| `editor.detectIndentation` | `false` | 自動検出せず設定されたtabSizeを使用 |
| `editor.tabSize` | `2` | デフォルトインデント幅（PythonとDockerfileは4） |

## セキュリティ設計

### NOPASSWD sudo

コンテナはワークスペースユーザーに対して `NOPASSWD:ALL` の sudo を設定しています。これは意図的な設計判断です：

- **開発専用コンテナ**: 本コンテナは使い捨てのシングルユーザー開発環境であり、本番サーバーではありません
- **プラグインインストール**: 一部のプラグイン（AWS CLI、AWS SAM CLI等）はシステム全体へのインストールに `sudo` が必要です
- **開発体験**: パスワードプロンプトを排除し、対話的シェル操作の摩擦を削減します

> **注意**: 本番ワークロードにはこのコンテナ設定を使用しないでください。NOPASSWD sudo はローカル開発環境専用の設定です。

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
- `clean-volumes.sh` - プロジェクトのDockerボリュームを全削除
- `clean-docker.sh` - 対話式Dockerリソースクリーンアップ（コンテナ、ビルドキャッシュ、イメージ、ネットワーク、ボリューム）

### 設定
- `workspace.toml` - ユーザー設定（コンテナ名、ユーザー名、プラグイン、ポート、VSCode拡張機能、カスタムボリューム）
- `config/workspace-settings.json.example` - デフォルトのVS Codeエディタ設定（`workspace-settings.json`にコピーしてカスタマイズ）
- `config/apt-base-packages.conf` - 全コンテナにインストールされるベースaptパッケージ
- `config/.bashrc_custom` - シェル起動時に読み込まれるユーザー固有のシェル設定

### プラグイン（`plugins/`）
- `plugins/aws-cli.toml` - AWS CLI v2プラグイン
- `plugins/aws-sam-cli.toml` - AWS SAM CLIプラグイン
- `plugins/claude-code.toml` - Claude Codeプラグイン
- `plugins/copilot-cli.toml` - GitHub Copilot CLIプラグイン
- `plugins/custom-ps1.toml` - Custom PS1プロンプトプラグイン（starshipと競合）
- `plugins/docker-cli.toml` - Docker CLIプラグイン（デフォルト: on）
- `plugins/github-cli.toml` - GitHub CLIプラグイン
- `plugins/go.toml` - Go言語プラグイン
- `plugins/lazygit.toml` - lazygitターミナルUIプラグイン
- `plugins/proto.toml` - protoバージョンマネージャープラグイン
- `plugins/rust.toml` - Rustツールチェーンプラグイン
- `plugins/starship.toml` - Starshipクロスシェルプロンプトプラグイン（custom-ps1と競合）
- `plugins/uv.toml` - uvパッケージマネージャープラグイン
- `plugins/zig.toml` - Zigコンパイラプラグイン

各プラグインTOMLには`[metadata]`（名前、説明、デフォルト）、`[install]`（Dockerfile命令）、`[version]`（ピン留めまたはlatest）が含まれます。

### ジェネレータ
- `lib/generators.py` - 全出力ファイルのプログラマティックジェネレータ（Dockerfile, docker-compose.yml, devcontainer.json, devcontainer docker-compose.yml）

### ライブラリ（`lib/`）

全 `lib/*.sh` は `set -uo pipefail`（`-e` なし）を使用します。これは意図的な設計です。これらのファイルはエントリポイントスクリプトから source されるため、`set -e` は呼び出し元に伝播し、算術式やサブシェルの戻り値で意図しない終了を引き起こします。`set -euo pipefail` はスタンドアロンのエントリポイントスクリプト（`setup-docker.sh`, `rebuild-container.sh`, `clean-volumes.sh`, `clean-docker.sh`）のみで使用します。

- `lib/generators.sh` - Python生成器ラッパー関数
- `lib/plugins.sh` - プラグイン読み込みとDockerfileスニペット生成
- `lib/utils.sh` - 汎用ユーティリティ（env解析、シンボリックリンク検証、Docker GID検出）
- `lib/certificates.sh` - 証明書の検証と管理
- `lib/toml_parser.py` - TOMLパーサー（Python 3.11+ tomllib）
- `lib/validators.sh` - 入力検証ライブラリ（サービス名、ユーザー名）
- `lib/i18n.sh` - 国際化フレームワーク（`msg()`, `msgln()`）
- `lib/logging.sh` - エラーハンドリングとメッセージングライブラリ
- `lib/colors.sh` - ターミナル出力用の共有カラー定数
- `lib/devcontainer.sh` - devcontainer CLIの前提条件チェックとWSL対応ラッパー

### メッセージカタログ（`locale/`）
- `locale/en.sh` - 英語メッセージ（デフォルト）
- `locale/ja.sh` - 日本語メッセージ

### テスト（`tests/`）
- `tests/run_all.sh` - 全8スイートのテストランナー
- `tests/test_helper.sh` - 共有アサーション関数
- `tests/test_*.sh` - 個別テストスイート

### CI/CD
- `.github/workflows/ci.yml` - GitHub Actionsワークフロー
  - ShellCheck静的解析
  - 8テストスイート実行
  - テンプレート検証とジェネレータ検証
  - HadolintによるDockerfile Lint
  - Dockerビルド検証

## i18n

すべてのユーザー向けメッセージは `lib/i18n.sh` フレームワークにより国際化対応しています。

### 仕組み

- メッセージカタログは `locale/en.sh`（英語、デフォルト）と `locale/ja.sh`（日本語）に格納されています。
- `WORKSPACE_LANG=ja` を設定すると日本語でメッセージが表示されます。デフォルトは英語です。
- 全スクリプトは `--lang ja` オプションも受け付けます（例: `bash setup-docker.sh --lang ja`）。
- メッセージは `printf` 形式の `%s` プレースホルダーで動的な値を埋め込みます。

### 関数

| 関数 | 出力 | 用途 |
|:-----|:-----|:-----|
| `msg key [args...]` | 改行なし（printf） | インライン展開: `info "$(msg key)"` |
| `msgln key [args...]` | 改行あり（printf） | 単独出力: `msgln key` |

### メッセージの追加方法

1. `locale/en.sh` にキーを追加: `_MSG[my_key]="English text %s"`
2. `locale/ja.sh` に翻訳を追加: `_MSG[my_key]="日本語 %s"`
3. スクリプトで使用: `msgln my_key "$value"` または `info "$(msg my_key "$value")"`

### 言語ポリシー

| コンテキスト | 言語 | 理由 |
|:-----------|:-----|:-----|
| ユーザー向け出力（TUI、echo） | 設定可能（EN/JA） | `WORKSPACE_LANG` で制御 |
| `logging.sh` 経由のログ/エラー | 設定可能（EN/JA） | `msg()` でメッセージ参照 |
| コードコメント | 英語 | GitHub 上の公開リポジトリ |
| ドキュメント | 英日両方 | `docs/*.md` と `docs/*.ja.md` を並行管理 |
