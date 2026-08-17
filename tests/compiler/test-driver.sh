#!/usr/bin/env bash
# Integration tests for the actual patched compiler. Never falls back to PATH.
set -euo pipefail
BIN=$(realpath "${1:-install/linux-x86_64/bin}")
for tool in neroclang neroclang++ neroclang-pp; do
  [[ -x "$BIN/$tool" ]] || { echo "missing built Nero tool: $BIN/$tool" >&2; exit 2; }
done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
printf 'int main(void){return 0;}\n' > "$TMP/test.c"

trace() { "$BIN/$1" "${@:2}" -### -c "$TMP/test.c" 2>&1; }
has_cc1_opt() { grep -q -- "\"-O$1\""; }
not_aggressive() { ! grep -Eq -- '"-O3"|"-flto|"-fPIC"|"-pic-level"|"-pie"|"-march=native"|FORTIFY_SOURCE|stack-protector'; }

trace neroclang | has_cc1_opt 2
trace neroclang-pp | has_cc1_opt 3
for pair in 'neroclang -O0 0' 'neroclang -Os s' 'neroclang-pp -O1 1' 'neroclang-pp -O2 2'; do
  read -r cc flag level <<<"$pair"; trace "$cc" "$flag" | has_cc1_opt "$level"
done
trace neroclang -fnero-fast | has_cc1_opt 3
trace neroclang -fnero-size | grep -q -- '"-Oz"'
trace neroclang -fnero-max | grep -q -- '"-flto'
trace neroclang -fnero-secure | grep -q -- 'FORTIFY_SOURCE=2'
trace neroclang-pp -fnero-kernel | not_aggressive
trace neroclang-pp -fnero-gki | not_aggressive
trace neroclang -fnero-diagnostics >/dev/null
"$BIN/neroclang" --version | grep -q '^Nero Clang 1.0.0$'
"$BIN/neroclang++" --version | grep -q '^Nero Clang 1.0.0$'
"$BIN/neroclang-pp" --version | grep -q '^Nero Clang PlusPlus 1.0.0$'
echo "Nero driver integration tests PASS"
