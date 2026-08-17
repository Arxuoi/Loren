#!/usr/bin/env python3
"""Nero tool manager. Compiler policy itself lives in the patched Clang driver."""
from __future__ import annotations
import argparse, json, os, platform, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path

VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parents[2]
LOGO = r""" _   _                 
| \ | | ___ _ __ ___  
|  \| |/ _ \ '__/ _ \ 
| |\  |  __/ | | (_) |
|_| \_|\___|_|  \___/ """
TARGETS = ("x86_64-linux-gnu", "aarch64-linux-gnu", "arm-linux-gnueabi",
           "arm-linux-gnueabihf", "aarch64-linux-android",
           "armv7a-linux-androideabi", "x86_64-linux-android")
PRESETS = {"balanced": ["-O2"], "speed": ["-O3"],
           "max-speed": ["-O3", "-flto", "-fuse-ld=lld"],
           "size": ["-Oz"],
           "secure": ["-O2", "-fstack-protector-strong", "-D_FORTIFY_SOURCE=2"],
           "debug": ["-O0", "-g"], "kernel": ["-fnero-kernel"],
           "android-kernel": ["-fnero-kernel"], "gki": ["-fnero-gki"]}

def bindir() -> Path:
    return Path(os.environ.get("NERO_HOME", Path(sys.argv[0]).resolve().parent.parent)) / "bin"

def compiler(cxx=False, pp=False) -> str:
    name = "neroclang-pp" if pp else ("neroclang++" if cxx else "neroclang")
    return str(bindir() / name)

def output(cmd, default="unavailable"):
    try: return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT).strip()
    except (OSError, subprocess.CalledProcessError): return default

def cmd_info(_):
    print(LOGO); print(f"Nero Clang version: {VERSION}\nLLVM version: 12.0.1")
    print(f"Host: {platform.machine()}-{platform.system().lower()}")
    print("Supported targets: " + ", ".join(TARGETS))
    cc = compiler(); print("Resource directory: " + output([cc, "-print-resource-dir"]))
    for label, tool in (("LLD", "ld.lld"), ("compiler-rt", "libclang_rt.builtins*"), ("libc++", "libc++.a")):
        found = shutil.which(tool, path=str(bindir())) or next(bindir().parent.glob("lib/**/"+tool), None)
        print(f"{label} status: {'available' if found else 'not installed'}")
    print("LTO status: " + ("available" if (bindir()/"ld.lld").exists() else "linker unavailable"))

def cmd_doctor(a):
    checks = {"compiler": Path(compiler()).exists(),
              "C++ compiler": Path(compiler(True)).exists(),
              "linker": (bindir()/"ld.lld").exists()}
    for t in ("llvm-ar", "llvm-nm", "llvm-objcopy", "llvm-objdump", "llvm-readelf", "llvm-strip"):
        checks[t] = (bindir()/t).exists()
    resource = output([compiler(), "-print-resource-dir"], "") if checks["compiler"] else ""
    checks["resource directory"] = bool(resource and Path(resource).is_dir())
    checks["C/C++ headers"] = any((bindir().parent/"include").glob("**/*"))
    checks["runtime"] = any((bindir().parent/"lib").glob("**/libclang_rt.*"))
    if checks["compiler"] and checks["linker"]:
        with tempfile.TemporaryDirectory() as d:
            src=Path(d)/"lto.c"; exe=Path(d)/"lto"; src.write_text("int main(void){return 0;}")
            checks["Full LTO"] = subprocess.run(
                [compiler(), "-flto", "-fuse-ld=lld", str(src), "-o", str(exe)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 and exe.exists()
    else: checks["Full LTO"] = False
    if a.kernel: checks["kernel-safe driver mode"] = Path(compiler()).exists()
    for k,v in checks.items(): print(f"{'PASS' if v else 'FAIL'}  {k}")
    raise SystemExit(0 if all(checks.values()) else 1)

def cmd_build(a):
    flags = PRESETS[a.preset]
    # Kernel presets contain only the native policy switch; Kbuild remains authoritative.
    cxx = any(Path(x).suffix in (".cc", ".cpp", ".cxx", ".C") for x in a.files)
    os.execvp(compiler(cxx, a.edition == "plusplus"), [compiler(cxx, a.edition == "plusplus"), *flags, *a.files])

def scan_kernel(path: Path):
    texts=[]
    for pattern in ("build.config*", "**/build.config*", "MODULE.bazel", "BUILD.bazel", ".config", "Makefile"):
        for p in list(path.glob(pattern))[:30]:
            try: texts.append(p.read_text(errors="ignore"))
            except OSError: pass
    text="\n".join(texts)
    branch = next((x for x in re.findall(r"android\d+-\d+\.\d+", text)), "unknown")
    arch = "arm64" if re.search(r"aarch64|arm64", text, re.I) else ("x86_64" if "x86_64" in text else "unknown")
    rev = re.search(r"(?:CLANG_VERSION|CLANG_PREBUILT_BIN|clang-r)(?:=|[^\n]*?)(r?\d+[a-z0-9]*)", text, re.I)
    lto = "ThinLTO" if "CONFIG_LTO_CLANG_THIN=y" in text else ("Full LTO" if "CONFIG_LTO_CLANG_FULL=y" in text else "not detected")
    return branch, arch, rev.group(1) if rev else None, lto, "CONFIG_CFI_CLANG=y" in text, "KMI_SYMBOL_LIST" in text

def cmd_gki(a):
    p=Path(a.path).resolve(); branch,arch,rev,lto,cfi,kmi=scan_kernel(p)
    compat = "UNKNOWN" if not rev else ("PASS" if re.search(r"(?:^|\D)12(?:\D|$)", rev) else "FAIL")
    kernel_support = "NOT RUN" if (p/"Makefile").exists() else "FAIL"
    overall = "UNKNOWN" if not rev else ("EXPERIMENTAL" if compat == "PASS" else "FAIL")
    print("Nero GKI Compatibility Report\n")
    print(f"Kernel: {branch}\nArchitecture: {arch}\nNero: {VERSION}\nLLVM: 12.0.1\n")
    print(f"Kernel compilation: {kernel_support}")
    print(f"Expected AOSP Clang: {rev or 'UNKNOWN'}\nToolchain version match: {compat}")
    print("KMI validation: NOT RUN")
    print(f"Overall GKI status: {overall}")
    print(f"Build metadata: {'Kleaf/Bazel' if (p/'MODULE.bazel').exists() else 'legacy/Make'}; LTO: {lto}; CFI: {cfi}; KMI: {kmi}\n")
    print("Reason:")
    print("Required AOSP Clang revision could not be proven." if not rev else
          ("Metadata appears LLVM-12-compatible; an actual ABI/KMI build is still required." if compat=="PASS" else "This branch expects a different Clang revision."))
    print("Nero may be suitable for experimentation, but is not ABI-identical to the official GKI toolchain.")

def cmd_kernel(a):
    p=Path(a.path).resolve(); env=os.environ.copy(); env.update(CC=compiler(), HOSTCC=compiler(), HOSTCXX=compiler(True), LD=str(bindir()/"ld.lld"), LLVM="1")
    if (p/"build/build.sh").exists() and a.build_config:
        env["BUILD_CONFIG"]=a.build_config; os.execve(p/"build/build.sh", [str(p/"build/build.sh")], env)
    os.execvpe("make", ["make", "-C", str(p), *a.make_args], env)

def cmd_benchmark(_):
    source='int main(){volatile unsigned long s=0;for(unsigned long i=0;i<20000000;i++)s+=i;return s==0;}'
    with tempfile.TemporaryDirectory() as d:
        src=Path(d)/"b.cpp"; src.write_text(source)
        for name, cc, flags in (("Nero Stable",compiler(True),[]),("Nero PlusPlus",compiler(pp=True),[]),("upstream Clang 12","clang++-12",["-O2"])):
            if not shutil.which(cc) and not Path(cc).exists(): print(f"{name}: UNSUPPORTED"); continue
            exe=Path(d)/(name.replace(" ","_")); t=time.monotonic(); r=subprocess.run([cc,*flags,str(src),"-o",str(exe)]); ct=time.monotonic()-t
            if r.returncode: print(f"{name}: FAIL"); continue
            t=time.monotonic(); subprocess.run([exe]); rt=time.monotonic()-t
            print(f"{name}: compile={ct:.4f}s size={exe.stat().st_size} bytes runtime={rt:.4f}s")

def parser():
    p=argparse.ArgumentParser(prog="nero", description="Nero Clang tool manager"); s=p.add_subparsers(dest="cmd")
    s.add_parser("info").set_defaults(fn=cmd_info); s.add_parser("version").set_defaults(fn=lambda _:print(f"Nero Clang {VERSION} (LLVM 12.0.1)"))
    s.add_parser("targets").set_defaults(fn=lambda _:print("\n".join(TARGETS))); s.add_parser("config").set_defaults(fn=lambda _:print(json.dumps({"home":str(bindir().parent),"version":VERSION},indent=2)))
    d=s.add_parser("doctor"); d.add_argument("--kernel",action="store_true"); d.set_defaults(fn=cmd_doctor)
    b=s.add_parser("build"); b.add_argument("files",nargs="+"); b.add_argument("--preset",choices=PRESETS,default="balanced"); b.add_argument("--edition",choices=("stable","plusplus"),default="stable"); b.set_defaults(fn=cmd_build)
    k=s.add_parser("build-kernel"); k.add_argument("path"); k.add_argument("--build-config"); k.add_argument("make_args",nargs=argparse.REMAINDER); k.set_defaults(fn=cmd_kernel)
    g=s.add_parser("gki-check"); g.add_argument("path",nargs="?",default="."); g.set_defaults(fn=cmd_gki)
    s.add_parser("benchmark").set_defaults(fn=cmd_benchmark); return p

def main():
    p=parser(); a=p.parse_args()
    if not a.cmd: print(LOGO); p.print_help(); return
    a.fn(a)
if __name__ == "__main__": main()
