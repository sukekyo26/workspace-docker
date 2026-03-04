---
name: copilot-agents-prompts
description: 'Create and manage Custom Agents (.github/agents/) and Prompt Files (.github/prompts/). Use when asked to: (1) Create a custom agent with tool restrictions, (2) Create a reusable prompt file, (3) Understand differences between agents, prompts, and skills. Triggers: "custom agent", "add agent", "create agent", "prompt file", "add prompt", "create prompt", "agent profile", "カスタムエージェント", "エージェント作成", "エージェント追加", "プロンプト作成", "プロンプト追加", "プロンプトファイル".'
---

# Copilot カスタマイズ: Agents & Prompts

Custom Agents と Prompt Files の新規作成ガイド。
Skills/Instructions は `copilot-customization` スキル、Hooks は `copilot-hooks` スキルを参照。

---

## 1. カスタムエージェントの作成 (`.github/agents/`)

ツール制限付きの専門ペルソナ。`@agent-name` で明示的に呼び出す。
GitHub.com上ではIssueに割り当て可能。

参照: https://docs.github.com/ja/copilot/concepts/agents/coding-agent/about-custom-agents

### ファイル形式

`.github/agents/<agent-name>.md`:

```markdown
---
name: my-agent
description: 'エージェントの目的と機能の説明'
tools: ['codebase', 'search', 'problems']
---

# エージェント名

エージェントの動作を定義するプロンプト本文。
```

### フロントマター

| フィールド | 必須 | 説明 |
|:-----------|:-----|:-----|
| `name` | Yes | エージェント名。ファイル名（拡張子除く）と一致推奨 |
| `description` | Yes | エージェントの目的と機能 |
| `tools` | No | アクセス可能ツールのリスト。省略時は全ツールアクセス可 |

### Skills との使い分け

| | Skills | Custom Agents |
|:--|:-------|:--------------|
| 呼出し | キーワードで自動選択 | `@name` で明示呼出し |
| ツール制限 | なし | `tools` で制限可能 |
| 用途 | タスクの手順・ナレッジ | ロール（役割）の定義 |
| GitHub.com | — | Issue割り当て可能 |

### エージェント作成チェックリスト

- [ ] `name` がファイル名と一致
- [ ] `tools` が役割に対して最小限に制限されている
- [ ] プロンプト本文が役割・手順・出力フォーマットを定義
- [ ] 「やらないこと」も明示（レビューエージェントなら「編集しない」等）

---

## 2. プロンプトファイルの作成 (`.github/prompts/`)

再利用可能なタスクプロンプト。VS Codeで `/prompt-name` で呼び出す。

参照: https://docs.github.com/ja/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file

### ファイル形式

`.github/prompts/<name>.prompt.md`:

```markdown
---
agent: 'agent'
description: 'プロンプトの目的説明'
tools: ['codebase', 'edit/editFiles']  # 任意
---

## タスク

タスク内容の説明。
${input:varName:ユーザーへの入力プロンプト}
```

### フロントマター

| フィールド | 必須 | 説明 |
|:-----------|:-----|:-----|
| `agent` | No | `'agent'` でAgentモードで実行 |
| `description` | Yes | プロンプトの目的説明 |
| `tools` | No | 使用ツールの制限 |

### 変数構文

- `${input:name:プロンプトテキスト}` — ユーザー入力を受け取る
- `${file:path/to/file}` — ファイル内容を埋め込む

### Prompt Files vs Skills vs Agents

| | Skills | Prompt Files | Custom Agents |
|:--|:-------|:-------------|:--------------|
| 呼出し | 自動選択 | `/name` | `@name` |
| 入力 | なし | `${input:...}` | なし |
| ツール制限 | なし | 任意 | 任意 |
| 用途 | ナレッジ提供 | タスク実行 | ロール定義 |

### プロンプト作成チェックリスト

- [ ] ファイル名が `<name>.prompt.md` の形式
- [ ] `description` が簡潔に目的を説明
- [ ] `${input:...}` で必要なユーザー入力を定義
- [ ] 手順が明確で再現性がある
