# Linux x86_64 validation — 2026-08-17

The installed compiler was built from patched upstream `llvmorg-12.0.1` and
validated without falling back to a compiler found on `PATH`.

## Passed

- Stable `-O2`, PlusPlus `-O3`, explicit optimization overrides, every native
  `-fnero-*` option, and kernel/GKI suppression (`tests/compiler/test-driver.sh`).
- C11, C17, C++11, C++14, C++17 compile/link/run, Full LTO through the built
  LLD, and five freestanding Linux/Android cross-target object generations
  (`tests/run-smoke.sh`).
- Built LLVM utilities, resource headers, compiler-rt, libc++, and libc++abi.
- Linux 5.10.0 x86_64 `bzImage` (9,702,080 bytes), rebuilt from the public
  `v5.10` tag using `-fnero-kernel` and the installed Nero compiler, LLD, and
  LLVM binutils. `tests/kernel/build-linux.sh` captures the tested invocation.
- Both Linux x86_64 archives passed `xz -t`; an extracted stable archive passed
  the driver integration and smoke suites.

## Incomplete or not run

- `check-llvm` was interrupted after 7,520 passes, 4 XFAIL, 207 unsupported,
  and one environment-related Go bindings failure. Go 1.24 module mode could
  not load LLVM 12's pre-module-layout bindings. Remaining tests were skipped.
- `check-clang` was interrupted after 1,518 passes, 8 XFAIL, and 19 unsupported;
  no failure had been reported at interruption. These partial runs are not
  represented as complete regression-suite passes.
- Android kernel and GKI ABI/KMI validation require a compatible Android Common
  Kernel checkout and official branch metadata; status remains not run/unknown.
- Native AArch64 and Windows hosts, and Android NDK sysroot linking, were not
  available in this environment.
