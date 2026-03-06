---
applyTo: "lib/**/*.sh,*.sh,plugins/**"
---

# Shell スクリプトのルール

- `awk -v var="$val"` は C スタイルのエスケープ解釈を行い `\` が消える。バックスラッシュを含む文字列は `ENVIRON["VAR"]` 経由で渡す
- Docker ソケットの GID（`stat`）とホストの `docker` グループ GID（`getent`）は異なる場合がある。GID のハードコードは行わない
- 動作環境で値が固定される場合は設定ファイルに切り出さずハードコードのままにする（過剰設計の防止）
- `lib/*.sh` で `trap ... EXIT` を使わない。source される関数内の trap は呼び出し元の EXIT trap を上書きする。一時ファイルは `if ! cmd; then rm -f "$tmp"; return 1; fi` パターンで直接 cleanup する
- パス前方一致で `=~` や `==` を使う場合、末尾に `/` を付与して prefix 誤マッチを防ぐ（例: `/home/user` が `/home/user2` にマッチする問題）。パスのマッチングに正規表現は使わない
