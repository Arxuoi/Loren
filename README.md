# Nero Clang 1.0.0

> **Linux x86_64 status: built and validated.** Nero Clang is compiled from the
> patched LLVM/Clang 12.0.1 source tree; it is not a wrapper around the system
> compiler. The validated Linux x86_64 archives are retained in `artifacts/` so
> they survive ephemeral build environments; generated build trees remain ignored.

Prebuilt Linux x86_64 packages and their SHA-256 checksums are available in the
[`artifacts/` directory](artifacts/). Verify a download before extracting it:

```sh
sha256sum -c SHA256SUMS
```

Nero Clang is a source-level customization of upstream LLVM/Clang **12.0.1**,
not a script which delegates compilation to the host compiler. The reproducible
bootstrap checks out the immutable `llvmorg-12.0.1` tag and applies the reviewed
native driver patch in `patches/llvm-12`. The installed `neroclang` names are
links to that newly built Clang binary; policy selection and Nero flags are
parsed inside Clang's table-generated option system.

## Validation status

The Linux x86_64 release was built from the patched `llvmorg-12.0.1` source on
a modern GCC 13 / Python 3.12 host. Stable and PlusPlus driver policies,
C11/C17, C++11/14/17, LLD Full LTO, compiler-rt, libc++, five freestanding
cross-target objects, and a complete Linux 5.10 x86_64 `bzImage` build have
been exercised with the installed Nero binaries. Android kernel, GKI ABI/KMI,
Windows host, and native AArch64 host builds remain **Not Yet Tested**. GKI
metadata results remain `UNKNOWN` unless an expected AOSP revision is found.
Exact commands, partial regression counts, and untested areas are recorded in
[docs/VALIDATION.md](docs/VALIDATION.md); partial suites are not reported as
complete passes.

| Capability | Linux x86_64 status |
| --- | --- |
| Patched Clang, LLD, LLVM utilities | **Tested** |
| Stable `-O2` / PlusPlus `-O3` policy | **Tested** |
| C11, C17, C++11, C++14, C++17 | **Tested: compile, link, run** |
| Full LTO through built LLD | **Tested** |
| Linux 5.10 x86_64 `bzImage` | **Tested** |
| Freestanding Linux/Android cross objects | **Tested** |
| Complete `check-llvm` / `check-clang` | **Incomplete** |
| Android kernel and GKI ABI/KMI | **Not Yet Tested / Unknown** |
| Native AArch64 and Windows hosts | **Not Yet Tested** |

## Nero versus Nero PlusPlus

* `neroclang` / `neroclang++`: compatibility edition, default `-O2` only when
  the caller supplies no optimization level.
* `neroclang-pp`: performance edition, default `-O3`. Full LTO is available,
  but remains opt-in except for `-fnero-max`. Explicit `-O*` always wins.
* Kernel modes do not inject edition defaults or userspace policy.

## Building and installing

Requirements are Git, CMake >=3.16, Ninja, Python 3, a C++17 bootstrap compiler,
and development packages required by LLVM. Builds are intentionally from source:

```sh
./build-nero.sh --edition stable --target linux-x86_64
./build-nero.sh --edition plusplus --target linux-aarch64
./build-nero.sh --all
export PATH="$PWD/install/linux-x86_64/bin:$PATH"
```

The AArch64 and MinGW targets require matching host cross toolchains/sysroots.
Packaging creates a `.tar.xz` (or Windows `.zip`) containing `bin`, `lib`,
`include`, `share`, licenses, README, and VERSION. Android proprietary content
and NDK files are never bundled.

### Verify the installed compiler

The three Nero entry points resolve to the newly built, patched `clang` binary.
The invocation name selects the edition inside the native driver:

```sh
install/linux-x86_64/bin/neroclang --version
install/linux-x86_64/bin/neroclang++ --version
install/linux-x86_64/bin/neroclang-pp --version
tests/compiler/test-driver.sh install/linux-x86_64/bin
tests/run-smoke.sh install/linux-x86_64/bin
NERO_HOME="$PWD/install/linux-x86_64" install/linux-x86_64/bin/nero doctor
```

Expected first lines are `Nero Clang 1.0.0` for Stable/C++ and
`Nero Clang PlusPlus 1.0.0` for the performance edition. The integration test
also rejects missing binaries instead of silently selecting a compiler from
`PATH`.

## Compiling C and C++

```sh
neroclang -std=c17 hello.c -o hello
neroclang++ -std=c++17 hello.cpp -o hello
neroclang-pp app.cpp -fnero-fast -o app
neroclang-pp app.cpp -fnero-max -fuse-ld=lld -o app
neroclang -### -fnero-size -c hello.c
```

Native switches are `-fnero-fast` (`-O3`), `-fnero-max` (`-O3 -flto`),
`-fnero-size` (`-Oz`), `-fnero-secure` (userspace hardening),
`-fnero-kernel`, `-fnero-gki`, and opt-in `-fnero-diagnostics`. Standard Clang
color flags remain supported. Normal diagnostic format remains the default for
build-tool parsers.

## Presets and CLI

`nero build FILE --preset balanced|speed|max-speed|size|secure|debug|kernel|android-kernel|gki`
selects declarative profiles. Other commands are `info`, `version`, `doctor
[--kernel]`, `targets`, `config`, `build-kernel`, `gki-check`, and `benchmark`.
Benchmark reports measured compile time, executable size, and runtime without
normalizing or hiding unavailable compilers.

## Cross compilation and Android NDK

Clang's upstream triples and ABI behavior are retained. Supply an external
sysroot; no automatic `-march=native` is used:

```sh
neroclang --target=aarch64-linux-gnu --sysroot=/opt/aarch64-sysroot -c a.c
neroclang++ --target=aarch64-linux-android21 \
  --sysroot="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot" a.cpp
```

## Linux kernel, Android kernel, and GKI

Put Nero `bin` first in `PATH` to support `make LLVM=1`; aliases for Clang,
LLD, and LLVM binutils are installed without changing their upstream behavior.
Alternatively select every tool explicitly. Never force PlusPlus or full LTO:
kernel `CONFIG_LTO*` and `CONFIG_CFI*` are authoritative. Android legacy and
Kleaf guidance, limitations, and honest GKI detection are in
[docs/KERNEL.md](docs/KERNEL.md). LLVM 12 is **not** claimed compatible with all
GKI branches or ABI-identical to any AOSP prebuilt.

The tested Linux 5.10 x86_64 invocation used Nero's kernel mode explicitly:

```sh
make O=out defconfig CC="/opt/nero/bin/neroclang -fnero-kernel"
make O=out -j$(nproc) bzImage \
  CC="/opt/nero/bin/neroclang -fnero-kernel" \
  HOSTCC="/opt/nero/bin/neroclang -fnero-kernel" \
  HOSTCXX="/opt/nero/bin/neroclang++ -fnero-kernel" \
  LD=/opt/nero/bin/ld.lld AR=/opt/nero/bin/llvm-ar \
  NM=/opt/nero/bin/llvm-nm OBJCOPY=/opt/nero/bin/llvm-objcopy \
  OBJDUMP=/opt/nero/bin/llvm-objdump STRIP=/opt/nero/bin/llvm-strip
```

The same validation is automated for an existing kernel checkout:

```sh
tests/kernel/build-linux.sh /path/to/linux-5.10 /tmp/nero-kernel-out bzImage
```

## LTO and testing

`tests/run-smoke.sh` compiles/runs C11, C17, C++11/14/17, creates and runs a
real full-LTO executable through LLD, and emits five freestanding cross-target
objects. After building, run it plus upstream regression suites:

```sh
tests/run-smoke.sh install/linux-x86_64/bin
cmake --build build/linux-x86_64 --target check-llvm check-clang
python3 -m unittest tests/test_cli.py
```

Kernel and Android kernel results must come from real source builds. A mismatch
with a branch-required newer AOSP revision is reported as **EXPECTED TOOLCHAIN
VERSION INCOMPATIBILITY**, never PASS.

## Troubleshooting

Use `nero doctor`, inspect translation with `neroclang -###`, verify the external
sysroot matches the target ABI, and reduce sensitive projects to `balanced` or
kernel mode. Recreate `llvm-project` if a local patch application was interrupted.

Licensed under Apache-2.0 WITH LLVM-exception; see [LICENSE](LICENSE).
