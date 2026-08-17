#!/usr/bin/env bash
set -euo pipefail
PREFIX=$(realpath "$1"); TARGET=$2; EDITION=$3; ROOT=$(cd "$(dirname "$0")/.." && pwd); OUT=$ROOT/artifacts
mkdir -p "$OUT"; stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
name=nero-clang; [[ $EDITION == plusplus ]] && name=nero-clang-plusplus
[[ $EDITION == all ]] && name=nero-clang
dir=$stage/$name-1.0.0; cp -a "$PREFIX" "$dir"; cp "$ROOT"/{README.md,LICENSE,VERSION} "$dir/"
mkdir -p "$dir/share/nero"; cp "$ROOT/nero/presets/presets.json" "$dir/share/nero/"
case $TARGET in
 windows-*) archive="$OUT/$name-1.0.0-$TARGET.zip"; (cd "$stage" && zip -qr "$archive" "$(basename "$dir")");;
 *) archive="$OUT/$name-1.0.0-$TARGET.tar.xz"; XZ_OPT=-T0 tar -C "$stage" -cJf "$archive" "$(basename "$dir")";;
esac
# Validate the staged layout, then extract Linux archives and execute the copy
# that was actually serialized.  This catches truncated or malformed packages.
for required in bin lib include share LICENSE README.md VERSION; do test -e "$dir/$required"; done
if [[ $TARGET != windows-* ]]; then
 verify=$(mktemp -d); tar -xJf "$archive" -C "$verify"
 "$verify/$(basename "$dir")/bin/neroclang" --version | grep -q '^Nero Clang 1.0.0$'
 rm -rf "$verify"
fi
echo "$OUT"
