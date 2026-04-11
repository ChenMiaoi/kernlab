#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence


ARCH_ALIASES = {
    "x86_64": "x86_64",
    "amd64": "x86_64",
    "arm": "arm",
    "arm32": "arm",
    "arm64": "arm64",
    "aarch64": "arm64",
    "aarch": "arm64",
    "riscv": "riscv",
    "riscv64": "riscv",
}

STANDARD_CROSS_PREFIXES = {
    "arm": (
        "arm-linux-gnueabihf-",
        "arm-linux-gnueabi-",
        "arm-none-linux-gnueabihf-",
    ),
    "arm64": (
        "aarch64-linux-gnu-",
        "aarch64-none-linux-gnu-",
    ),
    "riscv": (
        "riscv64-linux-gnu-",
        "riscv64-unknown-linux-gnu-",
    ),
}

PACKAGE_CANDIDATES = {
    "make": {
        "apt-get": [["build-essential"]],
        "dnf": [["make"]],
        "yum": [["make"]],
        "pacman": [["base-devel"]],
        "zypper": [["make"]],
        "apk": [["build-base"]],
    },
    "native_cc": {
        "apt-get": [["build-essential"]],
        "dnf": [["gcc"]],
        "yum": [["gcc"]],
        "pacman": [["base-devel"]],
        "zypper": [["gcc"]],
        "apk": [["build-base"]],
    },
    "perl": {
        "apt-get": [["perl"]],
        "dnf": [["perl"]],
        "yum": [["perl"]],
        "pacman": [["perl"]],
        "zypper": [["perl"]],
        "apk": [["perl"]],
    },
    "bc": {
        "apt-get": [["bc"]],
        "dnf": [["bc"]],
        "yum": [["bc"]],
        "pacman": [["bc"]],
        "zypper": [["bc"]],
        "apk": [["bc"]],
    },
    "bison": {
        "apt-get": [["bison"]],
        "dnf": [["bison"]],
        "yum": [["bison"]],
        "pacman": [["bison"]],
        "zypper": [["bison"]],
        "apk": [["bison"]],
    },
    "flex": {
        "apt-get": [["flex"]],
        "dnf": [["flex"]],
        "yum": [["flex"]],
        "pacman": [["flex"]],
        "zypper": [["flex"]],
        "apk": [["flex"]],
    },
    "readelf": {
        "apt-get": [["binutils"]],
        "dnf": [["binutils"]],
        "yum": [["binutils"]],
        "pacman": [["binutils"]],
        "zypper": [["binutils"]],
        "apk": [["binutils"]],
    },
    "file": {
        "apt-get": [["file"]],
        "dnf": [["file"]],
        "yum": [["file"]],
        "pacman": [["file"]],
        "zypper": [["file"]],
        "apk": [["file"]],
    },
    "cpio": {
        "apt-get": [["cpio"]],
        "dnf": [["cpio"]],
        "yum": [["cpio"]],
        "pacman": [["cpio"]],
        "zypper": [["cpio"]],
        "apk": [["cpio"]],
    },
    "gzip": {
        "apt-get": [["gzip"]],
        "dnf": [["gzip"]],
        "yum": [["gzip"]],
        "pacman": [["gzip"]],
        "zypper": [["gzip"]],
        "apk": [["gzip"]],
    },
    "ldd": {
        "apt-get": [["libc-bin"]],
        "dnf": [["glibc"]],
        "yum": [["glibc"]],
        "pacman": [["glibc"]],
        "zypper": [["glibc"]],
        "apk": [["libc-utils"]],
    },
    "python3": {
        "apt-get": [["python3"]],
        "dnf": [["python3"]],
        "yum": [["python3"]],
        "pacman": [["python"]],
        "zypper": [["python3"]],
        "apk": [["python3"]],
    },
    "python3_venv": {
        "apt-get": [["python3-venv"]],
        "dnf": [["python3"]],
        "yum": [["python3"]],
        "pacman": [["python"]],
        "zypper": [["python3"]],
        "apk": [["python3"]],
    },
    "ninja": {
        "apt-get": [["ninja-build"]],
        "dnf": [["ninja-build"]],
        "yum": [["ninja-build"]],
        "pacman": [["ninja"]],
        "zypper": [["ninja"]],
        "apk": [["ninja"]],
    },
    "pkg_config": {
        "apt-get": [["pkg-config"]],
        "dnf": [["pkgconf-pkg-config"], ["pkgconf"]],
        "yum": [["pkgconf-pkg-config"], ["pkgconf"]],
        "pacman": [["pkgconf"]],
        "zypper": [["pkg-config"]],
        "apk": [["pkgconf"]],
    },
    "libelf_headers": {
        "apt-get": [["libelf-dev"]],
        "dnf": [["elfutils-libelf-devel"]],
        "yum": [["elfutils-libelf-devel"]],
        "pacman": [["libelf"]],
        "zypper": [["libelf-devel"]],
        "apk": [["elfutils-dev"]],
    },
    "openssl_headers": {
        "apt-get": [["libssl-dev"]],
        "dnf": [["openssl-devel"]],
        "yum": [["openssl-devel"]],
        "pacman": [["openssl"]],
        "zypper": [["libopenssl-devel"]],
        "apk": [["openssl-dev"]],
    },
    "ncurses_headers": {
        "apt-get": [["libncurses-dev"], ["libncurses5-dev"]],
        "dnf": [["ncurses-devel"]],
        "yum": [["ncurses-devel"]],
        "pacman": [["ncurses"]],
        "zypper": [["ncurses-devel"]],
        "apk": [["ncurses-dev"]],
    },
    "clang": {
        "apt-get": [["clang"]],
        "dnf": [["clang"]],
        "yum": [["clang"]],
        "pacman": [["clang"]],
        "zypper": [["clang"]],
        "apk": [["clang"]],
    },
    "bear": {
        "apt-get": [["bear"]],
        "dnf": [["bear"]],
        "yum": [["bear"]],
        "pacman": [["bear"]],
        "zypper": [["bear"]],
    },
    "lld": {
        "apt-get": [["lld"]],
        "dnf": [["lld"]],
        "yum": [["lld"]],
        "pacman": [["lld"]],
        "zypper": [["lld"]],
        "apk": [["lld"]],
    },
    "llvm_tools": {
        "apt-get": [["llvm"]],
        "dnf": [["llvm"]],
        "yum": [["llvm"]],
        "pacman": [["llvm"]],
        "zypper": [["llvm"]],
        "apk": [["llvm"]],
    },
    "glib_headers": {
        "apt-get": [["libglib2.0-dev"]],
        "dnf": [["glib2-devel"]],
        "yum": [["glib2-devel"]],
        "pacman": [["glib2"]],
        "zypper": [["glib2-devel"]],
        "apk": [["glib-dev"]],
    },
    "pixman_headers": {
        "apt-get": [["libpixman-1-dev"]],
        "dnf": [["pixman-devel"]],
        "yum": [["pixman-devel"]],
        "pacman": [["pixman"]],
        "zypper": [["pixman-devel"]],
        "apk": [["pixman-dev"]],
    },
    "zlib_headers": {
        "apt-get": [["zlib1g-dev"]],
        "dnf": [["zlib-devel"]],
        "yum": [["zlib-devel"]],
        "pacman": [["zlib"]],
        "zypper": [["zlib-devel"]],
        "apk": [["zlib-dev"]],
    },
}

CROSS_GCC_PACKAGES = {
    "apt-get": {
        "arm": [["gcc-arm-linux-gnueabihf"], ["gcc-arm-linux-gnueabi"]],
        "arm64": [["gcc-aarch64-linux-gnu"]],
        "riscv": [["gcc-riscv64-linux-gnu"]],
    },
    "dnf": {
        "arm": [["gcc-arm-linux-gnu", "binutils-arm-linux-gnu"], ["gcc-arm-linux-gnu"]],
        "arm64": [["gcc-aarch64-linux-gnu", "binutils-aarch64-linux-gnu"], ["gcc-aarch64-linux-gnu"]],
        "riscv": [["gcc-riscv64-linux-gnu", "binutils-riscv64-linux-gnu"], ["gcc-riscv64-linux-gnu"]],
    },
    "yum": {
        "arm": [["gcc-arm-linux-gnu", "binutils-arm-linux-gnu"], ["gcc-arm-linux-gnu"]],
        "arm64": [["gcc-aarch64-linux-gnu", "binutils-aarch64-linux-gnu"], ["gcc-aarch64-linux-gnu"]],
        "riscv": [["gcc-riscv64-linux-gnu", "binutils-riscv64-linux-gnu"], ["gcc-riscv64-linux-gnu"]],
    },
    "pacman": {
        "arm": [["arm-linux-gnueabihf-gcc", "arm-linux-gnueabihf-glibc"], ["arm-linux-gnueabi-gcc", "arm-linux-gnueabi-glibc"]],
        "arm64": [["aarch64-linux-gnu-gcc", "aarch64-linux-gnu-glibc"]],
        "riscv": [["riscv64-linux-gnu-gcc", "riscv64-linux-gnu-glibc"]],
    },
}

CROSS_LIBC_PACKAGES = {
    "apt-get": {
        "arm": [["libc6-dev-armhf-cross"], ["libc6-dev-armel-cross"]],
        "arm64": [["libc6-dev-arm64-cross"]],
        "riscv": [["libc6-dev-riscv64-cross"]],
    },
    "dnf": {
        "arm": [["glibc-devel-arm-linux-gnu"], ["glibc-devel.armv7hl"]],
        "arm64": [["glibc-devel-aarch64-linux-gnu"], ["glibc-devel.aarch64"]],
        "riscv": [["glibc-devel-riscv64-linux-gnu"], ["glibc-devel.riscv64"]],
    },
    "yum": {
        "arm": [["glibc-devel-arm-linux-gnu"], ["glibc-devel.armv7hl"]],
        "arm64": [["glibc-devel-aarch64-linux-gnu"], ["glibc-devel.aarch64"]],
        "riscv": [["glibc-devel-riscv64-linux-gnu"], ["glibc-devel.riscv64"]],
    },
    "pacman": {
        "arm": [["arm-linux-gnueabihf-gcc", "arm-linux-gnueabihf-glibc"], ["arm-linux-gnueabi-gcc", "arm-linux-gnueabi-glibc"]],
        "arm64": [["aarch64-linux-gnu-gcc", "aarch64-linux-gnu-glibc"]],
        "riscv": [["riscv64-linux-gnu-gcc", "riscv64-linux-gnu-glibc"]],
    },
}


@dataclass(frozen=True)
class PackageManagerSpec:
    name: str
    binary: str
    update_cmd: tuple[str, ...] | None
    install_prefix: tuple[str, ...]
    env: dict[str, str]


PACKAGE_MANAGERS = {
    "apt-get": PackageManagerSpec(
        name="apt-get",
        binary="apt-get",
        update_cmd=("apt-get", "update"),
        install_prefix=("apt-get", "install", "-y"),
        env={"DEBIAN_FRONTEND": "noninteractive"},
    ),
    "dnf": PackageManagerSpec(
        name="dnf",
        binary="dnf",
        update_cmd=None,
        install_prefix=("dnf", "install", "-y"),
        env={},
    ),
    "yum": PackageManagerSpec(
        name="yum",
        binary="yum",
        update_cmd=None,
        install_prefix=("yum", "install", "-y"),
        env={},
    ),
    "pacman": PackageManagerSpec(
        name="pacman",
        binary="pacman",
        update_cmd=("pacman", "-Sy", "--noconfirm"),
        install_prefix=("pacman", "-S", "--noconfirm", "--needed"),
        env={},
    ),
    "zypper": PackageManagerSpec(
        name="zypper",
        binary="zypper",
        update_cmd=("zypper", "--non-interactive", "refresh"),
        install_prefix=("zypper", "--non-interactive", "install", "--no-recommends"),
        env={},
    ),
    "apk": PackageManagerSpec(
        name="apk",
        binary="apk",
        update_cmd=None,
        install_prefix=("apk", "add", "--no-cache"),
        env={},
    ),
}


@dataclass(frozen=True)
class Context:
    arch: str
    host_arch: str
    components: tuple[str, ...]
    cross_compile: str
    llvm: bool
    menuconfig: bool
    kernel_debug: bool
    busybox_static: str
    package_manager: str


@dataclass(frozen=True)
class Requirement:
    key: str
    description: str
    checker: Callable[[Context], bool]
    package_candidates: Callable[[Context], list[list[str]]]


def normalize_arch(value: str) -> str:
    arch = ARCH_ALIASES.get(value)
    if not arch:
        raise ValueError(f"Unsupported ARCH={value!r}. Use x86_64|arm|arm64|riscv.")
    return arch


def detect_package_manager() -> str:
    for name, spec in PACKAGE_MANAGERS.items():
        if shutil.which(spec.binary):
            return name
    known = ", ".join(PACKAGE_MANAGERS)
    raise RuntimeError(f"Unable to detect a supported package manager. Tried: {known}.")


def needs_cross_toolchain(ctx: Context) -> bool:
    return bool(ctx.cross_compile) or ctx.arch != ctx.host_arch


def candidate_cross_prefixes(ctx: Context) -> tuple[str, ...]:
    if ctx.cross_compile:
        return (ctx.cross_compile,)
    return STANDARD_CROSS_PREFIXES.get(ctx.arch, ())


def find_cross_compiler(ctx: Context) -> str | None:
    for prefix in candidate_cross_prefixes(ctx):
        compiler = f"{prefix}gcc"
        if shutil.which(compiler):
            return compiler
    return None


def has_any_command(*names: str) -> bool:
    return any(shutil.which(name) for name in names)


def pkg_config_binary() -> str | None:
    return shutil.which("pkg-config") or shutil.which("pkgconf")


def python_can_create_venv() -> bool:
    python = shutil.which("python3")
    if not python:
        return False
    result = subprocess.run(
        [python, "-m", "venv", "--help"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        text=True,
    )
    return result.returncode == 0


def pkg_config_package_available(package: str) -> bool:
    pkg_config = pkg_config_binary()
    if not pkg_config:
        return False
    result = subprocess.run(
        [pkg_config, "--exists", package],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        text=True,
    )
    return result.returncode == 0


def compile_test(compiler: str, source: str, extra_args: Sequence[str] | None = None) -> bool:
    args = list(extra_args or ())
    with tempfile.TemporaryDirectory(prefix="ensure-build-deps-") as temp_dir:
        src = Path(temp_dir) / "test.c"
        out = Path(temp_dir) / "test.out"
        src.write_text(source, encoding="utf-8")
        cmd = [compiler, *args, str(src), "-o", str(out)]
        result = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            text=True,
        )
    return result.returncode == 0


def header_is_available(header: str) -> bool:
    compiler = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang")
    if not compiler:
        return False
    source = f"#include <{header}>\nint main(void) {{ return 0; }}\n"
    return compile_test(compiler, source, ["-x", "c"])


def cross_header_is_available(ctx: Context, header: str) -> bool:
    compiler = find_cross_compiler(ctx)
    if not compiler:
        return False
    source = f"#include <{header}>\nint main(void) {{ return 0; }}\n"
    return compile_test(compiler, source, ["-x", "c"])


def static_link_is_available(ctx: Context) -> bool:
    if ctx.busybox_static != "1":
        return True
    compiler = find_cross_compiler(ctx)
    if compiler is None:
        compiler = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang")
    if compiler is None:
        return False
    source = "#include <math.h>\nint main(void) { return (int)sin(0.0); }\n"
    return compile_test(compiler, source, ["-x", "c", "-static", "-lm"])


def package_candidates_for(key: str, package_manager: str) -> list[list[str]]:
    return [list(group) for group in PACKAGE_CANDIDATES.get(key, {}).get(package_manager, [])]


def cross_gcc_packages(ctx: Context) -> list[list[str]]:
    return [list(group) for group in CROSS_GCC_PACKAGES.get(ctx.package_manager, {}).get(ctx.arch, [])]


def cross_libc_packages(ctx: Context) -> list[list[str]]:
    return [list(group) for group in CROSS_LIBC_PACKAGES.get(ctx.package_manager, {}).get(ctx.arch, [])]


def command_requirement(key: str, description: str, *commands: str) -> Requirement:
    return Requirement(
        key=key,
        description=description,
        checker=lambda _ctx: has_any_command(*commands),
        package_candidates=lambda ctx: package_candidates_for(key, ctx.package_manager),
    )


def native_cc_requirement() -> Requirement:
    return Requirement(
        key="native_cc",
        description="native C compiler",
        checker=lambda ctx: has_any_command("cc", "gcc") or (ctx.llvm and has_any_command("clang")),
        package_candidates=lambda ctx: package_candidates_for("native_cc", ctx.package_manager),
    )


def native_header_requirement(key: str, description: str, header: str) -> Requirement:
    return Requirement(
        key=key,
        description=description,
        checker=lambda _ctx: header_is_available(header),
        package_candidates=lambda ctx: package_candidates_for(key, ctx.package_manager),
    )


def pkg_config_package_requirement(key: str, description: str, package: str) -> Requirement:
    return Requirement(
        key=key,
        description=description,
        checker=lambda _ctx: pkg_config_package_available(package),
        package_candidates=lambda ctx: package_candidates_for(key, ctx.package_manager),
    )


def python_venv_requirement() -> Requirement:
    return Requirement(
        key="python3_venv",
        description="python3 venv support",
        checker=lambda _ctx: python_can_create_venv(),
        package_candidates=lambda ctx: package_candidates_for("python3_venv", ctx.package_manager),
    )


def cross_gcc_requirement() -> Requirement:
    return Requirement(
        key="cross_gcc",
        description="target cross compiler",
        checker=lambda ctx: (not needs_cross_toolchain(ctx)) or (find_cross_compiler(ctx) is not None),
        package_candidates=cross_gcc_packages,
    )


def cross_libc_requirement() -> Requirement:
    return Requirement(
        key="cross_libc",
        description="target libc headers for busybox",
        checker=lambda ctx: (not needs_cross_toolchain(ctx)) or cross_header_is_available(ctx, "byteswap.h"),
        package_candidates=cross_libc_packages,
    )


def static_libs_requirement() -> Requirement:
    return Requirement(
        key="static_libs",
        description="static libc/libm for busybox",
        checker=static_link_is_available,
        package_candidates=cross_libc_packages,
    )


def build_requirements(ctx: Context) -> list[Requirement]:
    requirements: list[Requirement] = []

    if "kernel" in ctx.components:
        requirements.extend(
            [
                command_requirement("make", "make", "make"),
                native_cc_requirement(),
                command_requirement("perl", "perl", "perl"),
                command_requirement("bc", "bc", "bc"),
                command_requirement("bison", "bison", "bison"),
                command_requirement("flex", "flex", "flex"),
                native_header_requirement("libelf_headers", "libelf development headers", "libelf.h"),
                native_header_requirement("openssl_headers", "OpenSSL development headers", "openssl/opensslv.h"),
            ]
        )
        if ctx.menuconfig:
            requirements.append(
                native_header_requirement("ncurses_headers", "ncurses development headers", "ncurses.h")
            )
        if ctx.llvm:
            requirements.extend(
                [
                    command_requirement("clang", "clang", "clang"),
                    command_requirement("lld", "lld", "ld.lld", "lld"),
                    command_requirement("llvm_tools", "llvm objcopy/nm tools", "llvm-objcopy", "llvm-nm"),
                ]
            )
        else:
            requirements.append(cross_gcc_requirement())
        if ctx.kernel_debug:
            requirements.append(command_requirement("bear", "bear", "bear"))

    if "busybox" in ctx.components:
        requirements.extend(
            [
                command_requirement("make", "make", "make"),
                native_cc_requirement(),
                command_requirement("readelf", "readelf", "readelf"),
                command_requirement("file", "file", "file"),
                cross_gcc_requirement(),
                cross_libc_requirement(),
            ]
        )
        if ctx.busybox_static == "1":
            requirements.append(static_libs_requirement())

    if "initramfs" in ctx.components:
        requirements.extend(
            [
                command_requirement("cpio", "cpio", "cpio"),
                command_requirement("gzip", "gzip", "gzip"),
                command_requirement("readelf", "readelf", "readelf"),
                command_requirement("file", "file", "file"),
                command_requirement("ldd", "ldd", "ldd"),
            ]
        )

    if "qemu" in ctx.components:
        requirements.extend(
            [
                command_requirement("make", "make", "make"),
                native_cc_requirement(),
                command_requirement("python3", "python3", "python3"),
                python_venv_requirement(),
                command_requirement("ninja", "ninja", "ninja"),
                command_requirement("pkg_config", "pkg-config", "pkg-config", "pkgconf"),
                pkg_config_package_requirement("glib_headers", "glib-2.0 development files", "glib-2.0"),
                pkg_config_package_requirement("pixman_headers", "pixman development files", "pixman-1"),
                pkg_config_package_requirement("zlib_headers", "zlib development files", "zlib"),
            ]
        )

    unique: list[Requirement] = []
    seen: set[str] = set()
    for requirement in requirements:
        if requirement.key in seen:
            continue
        seen.add(requirement.key)
        unique.append(requirement)
    return unique


def run_command(cmd: Sequence[str], env: dict[str, str] | None = None) -> None:
    full_cmd = list(cmd)
    if env:
        full_cmd = ["env", *(f"{key}={value}" for key, value in env.items()), *full_cmd]
    if os.geteuid() != 0:
        sudo = shutil.which("sudo")
        if not sudo:
            raise RuntimeError("Missing sudo. Re-run as root or install sudo so dependencies can be installed.")
        full_cmd = [sudo, *full_cmd]

    print("+", shlex.join(full_cmd))
    subprocess.run(full_cmd, check=True)


def evaluate_requirements(requirements: Sequence[Requirement], ctx: Context) -> list[Requirement]:
    missing: list[Requirement] = []
    for requirement in requirements:
        if requirement.checker(ctx):
            print(f"[ok] {requirement.description}")
        else:
            print(f"[missing] {requirement.description}")
            missing.append(requirement)
    return missing


def install_missing(requirements: Sequence[Requirement], ctx: Context, dry_run: bool) -> list[str]:
    spec = PACKAGE_MANAGERS[ctx.package_manager]
    updated = False
    unsupported: list[str] = []
    grouped: dict[tuple[tuple[str, ...], ...], list[Requirement]] = {}

    for requirement in requirements:
        candidates = requirement.package_candidates(ctx)
        if not candidates:
            unsupported.append(requirement.description)
            continue
        signature = tuple(tuple(group) for group in candidates)
        grouped.setdefault(signature, []).append(requirement)

    if unsupported:
        print(
            "No automatic package mapping is available for: " + ", ".join(unsupported),
            file=sys.stderr,
        )

    for signature, grouped_requirements in grouped.items():
        descriptions = ", ".join(req.description for req in grouped_requirements)
        candidate_groups = [list(group) for group in signature]
        installed = False

        for index, package_group in enumerate(candidate_groups):
            if dry_run:
                if spec.update_cmd and not updated:
                    preview = list(spec.update_cmd)
                    if spec.env:
                        preview = ["env", *(f"{key}={value}" for key, value in spec.env.items()), *preview]
                    if os.geteuid() != 0 and shutil.which("sudo"):
                        preview = ["sudo", *preview]
                    print("[dry-run]", shlex.join(preview))
                    updated = True

                preview = [*spec.install_prefix, *package_group]
                if spec.env:
                    preview = ["env", *(f"{key}={value}" for key, value in spec.env.items()), *preview]
                if os.geteuid() != 0 and shutil.which("sudo"):
                    preview = ["sudo", *preview]
                print(f"[dry-run] install {descriptions}: {shlex.join(preview)}")
                installed = True
                break

            try:
                if spec.update_cmd and not updated:
                    run_command(spec.update_cmd, spec.env)
                    updated = True
                print(f"Installing packages for {descriptions}: {' '.join(package_group)}")
                run_command([*spec.install_prefix, *package_group], spec.env)
                installed = True
                break
            except (RuntimeError, subprocess.CalledProcessError) as exc:
                attempt = index + 1
                print(f"Install attempt {attempt} for {descriptions} failed: {exc}", file=sys.stderr)

        if not installed:
            unsupported.append(descriptions)

    return unsupported


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check and install build dependencies for linux, busybox, initramfs, and qemu."
    )
    parser.add_argument(
        "--component",
        action="append",
        choices=("kernel", "busybox", "initramfs", "qemu"),
        required=True,
        help="Component to prepare dependencies for. Repeat to combine components.",
    )
    parser.add_argument(
        "--arch",
        default=os.environ.get("ARCH", "x86_64"),
        help="Target arch: x86_64|arm|arm64|riscv",
    )
    parser.add_argument(
        "--cross-compile",
        default=os.environ.get("CROSS_COMPILE", ""),
        help="Cross compiler prefix override, for example riscv64-linux-gnu-",
    )
    parser.add_argument(
        "--llvm",
        action="store_true",
        help="Kernel build uses LLVM toolchain instead of GCC cross toolchain.",
    )
    parser.add_argument(
        "--menuconfig",
        action="store_true",
        help="Also prepare menuconfig ncurses headers.",
    )
    parser.add_argument(
        "--kernel-debug",
        action="store_true",
        help="Kernel build also needs bear to refresh compile_commands.json for clangd.",
    )
    parser.add_argument(
        "--busybox-static",
        default=os.environ.get("BUSYBOX_STATIC", "auto"),
        choices=("auto", "0", "1"),
        help="Busybox static mode. auto means cross builds expect static linking.",
    )
    parser.add_argument(
        "--package-manager",
        choices=tuple(PACKAGE_MANAGERS),
        help="Override autodetected package manager.",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Only check dependencies and return non-zero if anything is missing.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the package-manager actions that would be taken without installing anything.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        arch = normalize_arch(args.arch)
        host_arch = normalize_arch(platform.machine())
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    try:
        package_manager = args.package_manager or detect_package_manager()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    busybox_static = args.busybox_static
    if busybox_static == "auto":
        busybox_static = "1" if arch != host_arch else "0"

    ctx = Context(
        arch=arch,
        host_arch=host_arch,
        components=tuple(dict.fromkeys(args.component)),
        cross_compile=args.cross_compile,
        llvm=args.llvm,
        menuconfig=args.menuconfig,
        kernel_debug=args.kernel_debug,
        busybox_static=busybox_static,
        package_manager=package_manager,
    )

    print(f"Using package manager: {package_manager}")
    print(f"Target arch: {arch} (host: {host_arch})")
    print(f"Components: {', '.join(ctx.components)}")

    requirements = build_requirements(ctx)
    missing = evaluate_requirements(requirements, ctx)
    if not missing:
        print("All required build dependencies are already available.")
        return 0

    if args.check_only:
        print("Missing build dependencies detected.", file=sys.stderr)
        return 1

    unsupported = install_missing(missing, ctx, args.dry_run)
    if args.dry_run:
        if unsupported:
            print("Dry-run completed with unsupported dependencies remaining.", file=sys.stderr)
            return 1
        print("Dry-run completed.")
        return 0

    print("Re-checking dependencies after installation...")
    remaining = evaluate_requirements(requirements, ctx)
    if remaining:
        descriptions = ", ".join(req.description for req in remaining)
        print(f"Dependency installation did not complete successfully: {descriptions}", file=sys.stderr)
        return 1

    print("Build dependencies are ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
