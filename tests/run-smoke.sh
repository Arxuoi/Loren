#!/usr/bin/env bash
set -euo pipefail
BIN=${1:-install/linux-x86_64/bin}; TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for std in c11 c17; do "$BIN/neroclang" -std=$std tests/c/hello.c -o "$TMP/$std"; "$TMP/$std"; done
for std in c++11 c++14 c++17; do "$BIN/neroclang++" -std=$std tests/cpp/hello.cpp -o "$TMP/${std//+/x}"; "$TMP/${std//+/x}"; done
"$BIN/neroclang-pp" tests/lto/full_lto.cpp -O3 -flto -fuse-ld=lld -Wl,--plugin-opt=save-temps -o "$TMP/lto"
"$TMP/lto"
"$BIN/llvm-readelf" -h "$TMP/lto" | grep -q "Class:"
for triple in aarch64-linux-gnu arm-linux-gnueabi aarch64-linux-android armv7a-linux-androideabi x86_64-linux-android; do
 "$BIN/neroclang" --target=$triple -ffreestanding -c tests/cross/freestanding.c -o "$TMP/$triple.o"
done
echo "smoke tests PASS"
