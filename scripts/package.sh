#!/usr/bin/env bash
set -euo pipefail
PREFIX=$(realpath "$1"); TARGET=$2; EDITION=$3; ROOT=$(cd "$(dirname "$0")/.." && pwd); OUT=$ROOT/artifacts
mkdir -p "$OUT"; stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
name=nero-clang; [[ $EDITION == plusplus ]] && name=nero-clang-plusplus
[[ $EDITION == all ]] && name=nero-clang
dir=$stage/$name-1.0.0; cp -a "$PREFIX" "$dir"; cp "$ROOT"/{README.md,LICENSE,VERSION} "$dir/"
case $TARGET in windows-*) (cd "$stage" && zip -qr "$OUT/$name-1.0.0-$TARGET.zip" "$(basename "$dir")");; *) tar -C "$stage" -cJf "$OUT/$name-1.0.0-$TARGET.tar.xz" "$(basename "$dir")";; esac
echo "$OUT"
