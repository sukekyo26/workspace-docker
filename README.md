# workspace-docker

Dockerを使用したUbuntu開発環境のテンプレートプロジェクトです。

## 概要

このプロジェクトは、Dockerコンテナ上でUbuntu開発環境を構築します。pyenv、Volta、AWS CLIなどの開発ツールがプリインストールされ、個人設定やインストール済みのバージョンは永続化されます。

## 前提条件

### Dockerのインストール

このプロジェクトを使用するには、Docker Engineがインストールされている必要があります。

Ubuntuの場合、以下のコマンドで簡単にインストールできます:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

詳細は公式ドキュメントを参照してください:
https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script

インストール後、現在のユーザーをdockerグループに追加することを推奨します:

```bash
sudo usermod -aG docker $USER
```

※ グループ変更を反映するには、再ログインが必要です。

## 必要なファイル

- `setup-docker.sh` - セットアップスクリプト
- `Dockerfile.template` - Dockerfileのテンプレート
- `docker-compose.yml.template` - docker-compose.ymlのテンプレート

## セットアップ手順

1. セットアップスクリプトを実行します:

```bash
bash setup-docker.sh
```

2. スクリプトの指示に従って以下の情報を入力します:
   - コンテナ名
   - ユーザー名

3. スクリプトが完了すると、`Dockerfile`と`docker-compose.yml`が自動生成されます。

## 使用方法

### Dockerイメージのビルド

```bash
docker compose build
```

### コンテナの起動

```bash
docker compose up -d
```

### コンテナへのアクセス

```bash
docker compose exec <サービス名> bash
```
`<サービス名>` は setup-docker.sh で入力した「container service name」です。

または、コンテナ名を直接指定する場合:

```bash
docker exec -it <コンテナ名> bash
```

※ `docker compose exec` を使用する方が推奨されます。

### コンテナの停止

```bash
docker compose down
```

### コンテナの確認

```bash
docker ps
```

## 注意事項

- テンプレートファイル（`Dockerfile.template`、`docker-compose.yml.template`）が必要です
- 生成された`Dockerfile`と`docker-compose.yml`は機密情報を含む可能性があるため、Gitで管理する際は注意してください
