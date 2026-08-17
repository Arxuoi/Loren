#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
VERSION=12.0.1
EDITION=stable TARGET=linux-x86_64 BUILD_TYPE=Release JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN)} PACKAGE=1
usage(){ echo "Usage: $0 [--edition stable|plusplus] [--all] [--target linux-x86_64|linux-aarch64|windows-x86_64] [--no-package]"; }
while (($#)); do case "$1" in
 --edition) EDITION=$2; shift 2;; --all) EDITION=all; shift;; --target) TARGET=$2; shift 2;;
 --no-package) PACKAGE=0; shift;; -h|--help) usage; exit;; *) echo "unknown option: $1" >&2; usage; exit 2;; esac; done
case $EDITION in stable|plusplus|all);; *) echo "invalid edition" >&2; exit 2;; esac
case $TARGET in linux-x86_64|linux-aarch64|windows-x86_64);; *) echo "invalid target" >&2; exit 2;; esac
SRC=$ROOT/llvm-project; BUILD=$ROOT/build/$TARGET; PREFIX=$ROOT/install/$TARGET
if [[ ! -f $SRC/llvm/CMakeLists.txt ]]; then
  command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
  git clone --depth 1 --branch llvmorg-$VERSION https://github.com/llvm/llvm-project.git "$SRC"
  git -C "$SRC" apply "$ROOT/patches/llvm-12/0001-nero-clang-driver.patch"
fi
mkdir -p "$SRC/nero/cli"; cp "$ROOT/nero/cli/nero.py" "$SRC/nero/cli/nero.py"
PROJECTS="clang;lld"; RUNTIMES="compiler-rt;libcxx;libcxxabi"
TOOLCHAIN=()
case $TARGET in
 linux-aarch64) TOOLCHAIN=(-DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu);;
 windows-x86_64) TOOLCHAIN=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu -DCMAKE_CXX_COMPILER_TARGET=x86_64-w64-windows-gnu);;
esac
cmake -S "$SRC/llvm" -B "$BUILD" -G Ninja \
 -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_INSTALL_PREFIX="$PREFIX" \
 -DLLVM_ENABLE_PROJECTS="$PROJECTS" -DLLVM_ENABLE_RUNTIMES="$RUNTIMES" \
 -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM" -DLLVM_ENABLE_TERMINFO=OFF \
 -DLLVM_ENABLE_ZLIB=ON -DCLANG_VENDOR="Nero Compiler Project" \
 -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG" -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG" \
 "${TOOLCHAIN[@]}"
cmake --build "$BUILD" --target clang lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip -j "$JOBS"
cmake --install "$BUILD"
install -Dm755 "$ROOT/nero/cli/nero.py" "$PREFIX/bin/nero"
for n in neroclang neroclang++ neroclang-pp; do ln -sfn clang "$PREFIX/bin/$n"; done
if ((PACKAGE)); then "$ROOT/scripts/package.sh" "$PREFIX" "$TARGET" "$EDITION"; fi
echo "Nero build complete: $PREFIX"
