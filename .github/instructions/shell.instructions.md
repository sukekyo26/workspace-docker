---
applyTo: "lib/**/*.sh,*.sh,plugins/**"
---

# Shell スクリプトのルール

- `awk -v var="$val"` は C スタイルのエスケープ解釈を行い `\` が消える。バックスラッシュを含む文字列は `ENVIRON["VAR"]` 経由で渡す
- Docker ソケットの GID（`stat`）とホストの `docker` グループ GID（`getent`）は異なる場合がある。GID のハードコードは行わない
- 動作環境で値が固定される場合は設定ファイルに切り出さずハードコードのままにする（過剰設計の防止）
- `lib/*.sh` で `trap ... EXIT` を使わない。source される関数内の trap は呼び出し元の EXIT trap を上書きする。一時ファイルは `if ! cmd; then rm -f "$tmp"; return 1; fi` パターンで直接 cleanup する
- パス前方一致で `=~` や `==` を使う場合、末尾に `/` を付与して prefix 誤マッチを防ぐ（例: `/home/user` が `/home/user2` にマッチする問題）。パスのマッチングに正規表現は使わない
- `lib/*.sh` は `set -uo pipefail`（`-e` なし）を使う。sourced script の `set -e` は呼び出し元のエラー処理に影響し、算術式やサブシェルで意図しない exit を起こす。`set -euo pipefail` はエントリポイントスクリプトのみで使用する
- `declare -n`（nameref）使用後は `unset -n` で参照を解放する。解放しないとグローバルスコープに変数が残存する
- `.env` 等の設定ファイル生成で here-doc を使う場合、変数展開させないために `<< 'EOF'` を使い、値は `printf '%s\n'` で安全に書き込む
- プラグイン追加時は `.github/workflows/ci.yml` の `docker-build` ジョブのプラグインリストにも追加する。CI でビルドテストされないプラグインは品質が保証されない
- プラグイン追加時は `tests/unit/plugins/test_<name>.sh` のユニットテストも作成する。既存テスト（例: `test_go.sh`）をテンプレートにする
- プラグインで `curl | sh` パターン（外部スクリプトをダウンロードして実行）を使う場合、`install_script_sha256` による SHA256 検証を必須とする。Dockerfile スニペットに `echo "{{INSTALL_SCRIPT_SHA256}}  /tmp/script.sh" | sha256sum -c -` を含め、`[version]` に `install_script_sha256` フィールドを設定する
