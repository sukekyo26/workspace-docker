# GitHub Copilot Instructions

> **重要**: このファイルはAIエージェント動作規約の生命線。「カスタマイズ体系の自己改善」に従い最新を維持すること。
> **行数制限**: 本ファイルは**100行前後**を維持する。肥大化はコンテキストウィンドウを圧迫し品質を下げる。

### セッション開始手順（MUST — 省略厳禁・最優先で実行）

**全てのセッションで、ユーザーの依頼に取り掛かる前に必ず以下を実行すること。**

1. `gh run list --limit 1` で最新 CI 結果を確認する（失敗時はタスクの最初に CI 修正を入れる）
2. `agent/lessons.md` を **read_file で全行通読**する（上限超過なら古いエントリを削除）
3. エントリが6件以上なら卒業判断を実施する（後述の運用ルール参照）
4. 複雑なタスクは `manage_todo_list` で計画を立ててから着手する
   - **末尾に「卒業判断」タスクを必ず含める**（lessons.md が6件以上の場合）

---

## コア原則

- **シンプル第一**: 変更は最小限に。影響範囲を最小化する
- **手を抜かない**: 根本原因を見つける。シニアエンジニアの水準を保つ
- **DRY原則**: 同じロジックを複数箇所に書かない

---

## エージェント作業規範

### 作業中ルール

- **プロ意識**: 「スタッフエンジニアはこれを承認するか？」と常に自問する
- **検証**: テストしてから完了とする
- **エレガントさ**: ハック的修正に感じたら立ち止まる
- **自律性**: バグレポート・CI失敗は言われずに修正する
- **依頼の正確な実行**: ユーザーの依頼内容をすり替えない。思い込みで別の作業をしない
- **指摘を受けたら**: その場で `agent/lessons.md` に記録する

### lessons.md 運用ルール

**上限**: 10エントリ / 80行。肥大化はコンテキストウィンドウを圧迫し全作業品質を下げる。

- **記録**: 指摘を受けたらその場で記録（日付・問題・ルール）。類似は統合。1エントリ最大8行
- **卒業（6件到達時）**: 類似統合 → 残存エントリの昇格先を「カスタマイズファイルの選択基準」表で判断 → 対応スキルを read_file で読み → 昇格案をユーザーに提案（勝手に変更しない） → 承認後に作成

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

### カスタマイズファイルの選択基準

| 選択基準 | 対応先 |
|:---------|:-------|
| プロジェクト全体に常時適用すべきルール | `copilot-instructions.md` |
| 特定ディレクトリのファイル操作時に適用すべき規約 | `.github/instructions/` |
| 複数ステップの手順やドメイン知識（キーワードで自動発動） | `.github/skills/` |
| ツールを制限した専門ロールが必要 | `.github/agents/` |
| ユーザーが `/name` で繰り返し呼ぶ定型タスク | `.github/prompts/` |
| 人間の判断不要で機械的に強制すべきチェック | `.github/hooks/` |

---

## カスタマイズ体系の自己改善

**このセクションは本ファイルで最も重要。** カスタマイズ体系が古くなれば全作業品質に影響する。

### 原則
- 常に批判的な目でカスタマイズ体系全体を見る。忖度しない
- **肥大化させない**: 本ファイルは**100行前後**。各カスタマイズファイルの理想上限 — Skills: 200行 / Instructions: 30行 / Agents: 50行 / Prompts: 50行 / Hooks: 30行
- 陳腐化した記載は削除・統合する

### 卒業との関係
- **卒業**: lessons.md 6件到達時に、エントリを上記の適切なファイルへ昇格する作業
- **自己改善**: 作業中にカスタマイズ体系の問題に気づいた時の改善提案
- 両者は独立したトリガー。卒業は自己改善の一形態だが、自己改善は卒業に限らない

### プロセス
1. **改善案をユーザーに提案する**（勝手に変更しない）
2. 「なぜ必要か」と「どのファイルを変更すべきか」を明示する
3. 新規ファイル作成時は対応スキルを read_file で読み込み、手順に従う
   - Skills/Instructions → `copilot-customization` / Agents/Prompts → `copilot-agents-prompts` / Hooks → `copilot-hooks`
