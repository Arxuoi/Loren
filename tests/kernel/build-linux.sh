#!/usr/bin/env bash
# Build a real x86_64 kernel with the installed Nero toolchain.
set -euo pipefail

KERNEL=$(realpath "${1:?usage: $0 KERNEL_SOURCE [OUTPUT_DIRECTORY] [TARGET]}")
OUT=$(realpath -m "${2:-$KERNEL/out-nero}")
TARGET=${3:-bzImage}
BIN=$(realpath "${NERO_BIN:-install/linux-x86_64/bin}")

for tool in neroclang neroclang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip; do
  [[ -x "$BIN/$tool" ]] || { echo "missing Nero build tool: $BIN/$tool" >&2; exit 2; }
done
[[ -f "$KERNEL/Makefile" ]] || { echo "not a Linux kernel source tree: $KERNEL" >&2; exit 2; }

common=(
  -C "$KERNEL" O="$OUT"
  CC="$BIN/neroclang -fnero-kernel"
  HOSTCC="$BIN/neroclang -fnero-kernel"
  HOSTCXX="$BIN/neroclang++ -fnero-kernel"
  LD="$BIN/ld.lld" AR="$BIN/llvm-ar" NM="$BIN/llvm-nm"
  OBJCOPY="$BIN/llvm-objcopy" OBJDUMP="$BIN/llvm-objdump"
  STRIP="$BIN/llvm-strip" LLVM_IAS=1
)

make "${common[@]}" defconfig
make "${common[@]}" -j"${JOBS:-$(getconf _NPROCESSORS_ONLN)}" "$TARGET"

image="$OUT/arch/x86/boot/$TARGET"
[[ -s "$image" ]] || { echo "kernel target did not produce $image" >&2; exit 1; }
echo "Nero Linux kernel build PASS: $image ($(stat -c %s "$image") bytes)"
