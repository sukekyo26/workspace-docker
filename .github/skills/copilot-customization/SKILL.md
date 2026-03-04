---
name: copilot-customization
description: 'Create and manage Agent Skills (.github/skills/) and Custom Instructions (.github/instructions/). Use when asked to: (1) Create a new agent skill, (2) Add or update custom instructions, (3) Understand the Copilot customization file structure. Triggers: "create skill", "new skill", "add skill", "custom instructions", "add instructions", "copilot customization", "agent skill", "SKILL.md", "instructions.md", "スキル作成", "新しいスキル", "スキル追加", "カスタム指示", "インストラクション追加", "カスタマイズ".'
---

# Copilot カスタマイズ: Skills & Instructions

Agent Skills と Custom Instructions の新規作成・更新ガイド。
カスタムエージェント・プロンプトは `copilot-agents-prompts` スキル、Hooks は `copilot-hooks` スキルを参照。

## ファイル体系（全5種類）

```
.github/
├── copilot-instructions.md          # 全体共通ルール（常に読み込まれる）
├── skills/<name>/SKILL.md           # エージェントスキル（本スキルで解説）
├── instructions/<対象>.instructions.md  # カスタムインストラクション（本スキルで解説）
├── agents/<name>.md                 # カスタムエージェント → copilot-agents-prompts
├── prompts/<name>.prompt.md         # プロンプトファイル → copilot-agents-prompts
└── hooks/<name>.json                # フック → copilot-hooks
```

---

## 1. エージェントスキルの作成 (`.github/skills/`)

Copilot が特定タスク実行時にキーワードマッチングで自動読込する指示フォルダ。
`SKILL.md`（必須）を `.github/skills/<skill-name>/` に配置。

参照: https://docs.github.com/ja/copilot/concepts/agents/about-agent-skills

### SKILL.md フロントマター

```yaml
---
name: my-skill-name  # フォルダ名と一致、小文字・ハイフンのみ
description: '機能説明。Use when asked to: (1) ..., (2) .... Triggers: "keyword", "日本語".'
---
```

`description` は自動発見の唯一のメカニズム。**WHAT** + **WHEN** + **Triggers**（英語+日本語）を必ず含める。

### スキル作成チェックリスト

- [ ] `name` がフォルダ名と完全一致、`description` にWHAT/WHEN/Triggers
- [ ] **Triggers に日本語キーワード含む**。本文500行以内

---

## 2. カスタムインストラクションの作成 (`.github/instructions/`)

特定のファイルパターンに自動適用されるルール。`applyTo` グロブパターンにマッチするファイルを操作する際に自動で読み込まれる。

参照: https://docs.github.com/ja/copilot/how-tos/configure-custom-instructions/add-repository-instructions

### ファイル形式

`<対象>.instructions.md`:

```markdown
---
applyTo: "src/**"
---

# このディレクトリのルール

- ルール1
- ルール2
```

### 命名規則

`<対象>.instructions.md` — 対象はディレクトリ名や機能名（例: `src`, `tests`, `definitions`）

### `copilot-instructions.md` との使い分け

| ファイル | スコープ | 用途 |
|:---------|:---------|:-----|
| `copilot-instructions.md` | プロジェクト全体 | 全体共通ルール・ワークフロー |
| `<対象>.instructions.md` | 特定ディレクトリ | ディレクトリ固有のアーキテクチャ・規約 |

### インストラクション作成チェックリスト

- [ ] ファイル名が `<対象>.instructions.md` の形式
- [ ] `applyTo` グロブパターンが正しく設定されている
- [ ] `copilot-instructions.md` と内容が重複していない
- [ ] **30行以内**で簡潔にまとまっている
