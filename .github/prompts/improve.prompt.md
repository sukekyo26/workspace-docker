---
agent: 'agent'
description: 'PROJECT_EVALUATION.md の改善タスクを実行する定型ワークフロー'
---

以下の改善タスクを実行してください。

${input:tasks:実行する改善タスクを入力（PROJECT_EVALUATION.md からコピー）}

## ワークフロー

### 1. カスタマイズ体系の事前チェック

${file:.github/copilot-instructions.md} の「カスタマイズファイルの選択基準」を確認し、今回の修正内容でエージェントカスタマイズ体系に追加すべきルールがあれば先に追加する。

### 2. 実装

- 後方互換性のための複雑化は不要。シンプルな設計を優先する
- 修正後は `bash tests/run_all.sh` を実行し、全テストがパスすることを確認する

### 3. コミット

関連する修正単位で英語 1 文のコミットメッセージを作成する。
形式: `type: description`（例: `fix: use printf for .env generation`）

### 4. ドキュメント更新

- `CHANGELOG.md` と `docs/CHANGELOG.ja.md` を更新する（`.github/` 配下の変更は記載しない）
- `local/PROJECT_EVALUATION.md` のスコア・採点内訳・悪い点・改善タスクを更新する
  - **`local/PROJECT_EVALUATION.md` は git 管理外のためコミット禁止**

### 5. 品質確認

修正中に新たな課題を発見した場合は `local/PROJECT_EVALUATION.md` にタスクとして追加する。
