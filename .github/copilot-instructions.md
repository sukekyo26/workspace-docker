# GitHub Copilot Instructions

> **重要**: このファイルはAIエージェント動作規約の生命線。「カスタマイズ体系の自己改善」に従い最新を維持すること。
> **行数制限**: 本ファイルは**100行前後**を維持する。肥大化はコンテキストウィンドウを圧迫し品質を下げる。

## 会話のルール

すべての回答は日本語で行うこと。

---

## コア原則

- **シンプル第一**: 変更は最小限に。影響範囲を最小化する
- **手を抜かない**: 根本原因を見つける。シニアエンジニアの水準を保つ
- **DRY原則**: 同じロジックを複数箇所に書かない

---

## ワークフロー設計

### セッション開始手順（MUST — 省略禁止）

1. `agent/lessons.md` を **read_file で全行通読**する（上限超過なら古いエントリを削除）
2. 複雑なタスクは `manage_todo_list` で計画を立ててから着手する

### 作業中ルール

- **プロ意識**: 「スタッフエンジニアはこれを承認するか？」と常に自問する
- **検証**: テストしてから完了とする
- **エレガントさ**: ハック的修正に感じたら立ち止まる
- **自律性**: バグレポート・CI失敗は言われずに修正する
- **依頼の正確な実行**: ユーザーの依頼内容をすり替えない。思い込みで別の作業をしない
- **指摘を受けたら**: その場で `agent/lessons.md` に記録する

### lessons.md 運用ルール

**上限**: 10エントリ / 100行。肥大化はコンテキストウィンドウを圧迫し全作業品質を下げる。

| タイミング | やること |
|:-----------|:---------|
| 指摘を受けた時 | その場で記録（日付・問題・ルール） |
| エントリ追加時 | 類似エントリは統合。1エントリ = 最大8行 |
| 卒業判断時 | 1週間以上残存するエントリは instructions/skills への昇格をユーザーに提案 |

---

## エージェント管理フォルダ (`./agent/`)

| ファイル | 用途 | コミット |
|:---------|:-----|:---------|
| `lessons.md` | 修正・学びの記録（10エントリ/100行上限） | 必要 |

---

## エージェントカスタマイズ体系

5種類のファイルでエージェント動作をカスタマイズしている。
新規作成時は対応スキルを参照: `copilot-customization`(Skills/Instructions) / `copilot-agents-prompts`(Agents/Prompts) / `copilot-hooks`(Hooks)。

| 種類 | 配置先 | 機能 |
|:-----|:-------|:-----|
| **Agent Skills** | `.github/skills/<name>/SKILL.md` | 特定タスク実行時に自動読込される指示（[参照](https://docs.github.com/ja/copilot/concepts/agents/about-agent-skills)） |
| **Custom Instructions** | `.github/instructions/<対象>.instructions.md` | 特定ファイルパターンに自動適用されるルール（[参照](https://docs.github.com/ja/copilot/how-tos/configure-custom-instructions/add-repository-instructions)） |
| **Custom Agents** | `.github/agents/<name>.md` | ツール制限付きの専門ペルソナ。`@name` で明示呼出し（[参照](https://docs.github.com/ja/copilot/concepts/agents/coding-agent/about-custom-agents)） |
| **Prompt Files** | `.github/prompts/<name>.prompt.md` | 再利用可能なタスクプロンプト。`/name` で呼出し（[参照](https://docs.github.com/ja/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file)） |
| **Hooks** | `.github/hooks/<name>.json` | ワークフロー内の特定ポイントでシェルコマンド自動実行（[参照](https://docs.github.com/ja/copilot/concepts/agents/coding-agent/about-hooks)） |

---

## カスタマイズ体系の自己改善

**このセクションは本ファイルで最も重要。** カスタマイズ体系が古くなれば全作業品質に影響する。

### 原則
- 常に批判的な目でカスタマイズ体系全体を見る。忖度しない
- **肥大化させない**: 本ファイルは**100行前後**、スキルは**200行以内**、インストラクションは**30行以内**が理想
- 陳腐化した記載は削除・統合する

### 改善対象の選択

| 改善内容 | 対応先 |
|:---------|:-------|
| 全体共通ルール・ワークフロー | `copilot-instructions.md` |
| 特定ディレクトリの規約 | `.github/instructions/<対象>.instructions.md` |
| 反復タスクの手順・ナレッジ | `.github/skills/<name>/SKILL.md` |
| ツール制限付き専門ロール | `.github/agents/<name>.md` |
| 繰り返し実行するタスク定義 | `.github/prompts/<name>.prompt.md` |
| エージェント動作の自動制御 | `.github/hooks/<name>.json` |

### プロセス
1. **改善案をユーザーに提案する**（勝手に変更しない）
2. 「なぜ必要か」と「どのファイルを変更すべきか」を明示する
3. 新規ファイル作成時は対応スキルの手順に従う
