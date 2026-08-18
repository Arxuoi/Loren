# Nero Clang 1.0.0 — Linux x86_64

This release contains binaries built from patched upstream LLVM/Clang 12.0.1.

Assets:

- `nero-clang-1.0.0-linux-x86_64.tar.xz` — Stable edition, default `-O2`.
- `nero-clang-plusplus-1.0.0-linux-x86_64.tar.xz` — performance edition,
  default `-O3`; Full LTO remains available through LLD.
- `SHA256SUMS` — checksums for both archives.

Both archives passed XZ integrity checks. The Stable archive was extracted and
passed native driver policy tests, C11/C17 and C++11/14/17 compile-link-run
tests, Full LTO through the bundled LLD, and freestanding Linux/Android object
generation. Linux v5.10 x86_64 was also built through `bzImage` with this
toolchain. See `docs/VALIDATION.md` for incomplete and untested areas.

Android NDK files and proprietary sysroots are intentionally not included.
Android kernel/GKI ABI/KMI compatibility is not claimed.
