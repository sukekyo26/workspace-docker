---
name: copilot-hooks
description: 'Create and manage Copilot Hooks (.github/hooks/) for automated workflow control. Use when asked to: (1) Configure hooks for agent workflow automation, (2) Add pre/post tool use checks, (3) Set up session start/end scripts, (4) Block dangerous commands. Triggers: "hooks", "add hook", "create hook", "preToolUse", "postToolUse", "sessionStart", "agent hook", "フック追加", "フック作成", "フック設定", "自動実行", "ワークフロー自動化".'
---

# Copilot カスタマイズ: Hooks

エージェントのワークフロー内の特定ポイントでシェルコマンドを自動実行する仕組み。
Skills/Instructions は `copilot-customization` スキル、Agents/Prompts は `copilot-agents-prompts` スキルを参照。

参照: https://docs.github.com/ja/copilot/concepts/agents/coding-agent/about-hooks

---

## フックの種類

| フック | タイミング | 主な用途 |
|:-------|:-----------|:---------|
| `sessionStart` | セッション開始時 | 環境初期化、ログ開始 |
| `sessionEnd` | セッション終了時 | クリーンアップ、レポート生成 |
| `userPromptSubmitted` | プロンプト送信時 | 監査ログ |
| `preToolUse` | ツール使用前 | 危険コマンドブロック、セキュリティチェック |
| `postToolUse` | ツール使用後 | 結果ログ、メトリクス |
| `agentStop` | エージェント完了時 | 最終処理 |
| `subagentStop` | サブエージェント完了時 | 結果検証 |
| `errorOccurred` | エラー発生時 | エラーログ、通知 |

## フック設定ファイル形式

`.github/hooks/<hook-name>.json`:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "./scripts/security-check.sh",
        "cwd": ".",
        "timeoutSec": 15
      }
    ]
  }
}
```

## 注意事項

- フックは**同期実行**でエージェントをブロックする — 実行時間は5秒以下を目安にする
- 入力は必ずバリデーション・サニタイズする
- トークン・パスワード等の機密データをログに記録しない
- 適切なタイムアウトを設定する

## フック作成チェックリスト

- [ ] JSON形式で `version: 1` が設定されている
- [ ] 実行スクリプトのパスが正しい
- [ ] `timeoutSec` が適切に設定されている
- [ ] 機密データのログ出力がない
