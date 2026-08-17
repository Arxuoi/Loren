# Kernel and GKI integration

Nero's `kernel`, `android-kernel`, and `gki` profiles deliberately add no
optimization, LTO, CFI, PIC/PIE, stack-protector, libc, or CPU tuning flags.
Kbuild and `.config` are authoritative. Use `make LLVM=1` after putting Nero's
`bin` first on `PATH`, or set `CC=neroclang HOSTCC=neroclang
HOSTCXX=neroclang++ LD=ld.lld` and the matching LLVM utilities explicitly.

For legacy Android trees run `nero build-kernel TREE --build-config
common/build.config.gki.aarch64`. For Kleaf, declare Nero as a custom Clang
toolchain using that branch's documented Bazel toolchain interface; interfaces
vary, so Nero never edits the tree. Run `nero gki-check TREE` first. `PASS`
means only that metadata explicitly selected LLVM 12; strict ABI/KMI
compatibility still requires the branch's complete build and ABI test suite.
`UNKNOWN` is intentionally returned when the expected revision cannot be found.
