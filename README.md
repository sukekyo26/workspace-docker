# workspace-docker

Dockerを使用した開発環境のワークスペースです。

## 概要

このプロジェクトは、Dockerコンテナ上でUbuntu環境を構築するためのセットアップスクリプトを提供します。

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
