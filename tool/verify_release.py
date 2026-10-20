#!/usr/bin/env python3
"""Inspect locally built Linux packages as data; never run/install their payloads."""
import argparse
import hashlib
import io
import pathlib
import struct
import subprocess
import tarfile
import tempfile
import xml.etree.ElementTree as ET

ARCHES = {"x86_64": (62, "amd64"), "aarch64": (183, "arm64")}
FORMATS = ("AppImage", "AppImage.zsync", "deb", "rpm", "pkg.tar.zst", "tar.gz", "flatpak")
ELFS = ("atyaf", "lib/libapp.so", "lib/libflutter_linux_gtk.so")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, f"{args[0]} failed: {result.stderr.decode(errors='replace')}")
    return result.stdout


def elf_header(header, arch, label):
    require(arch in ARCHES, f"Unsupported Linux architecture: {arch}")
    require(len(header) >= 20 and header[:6] == b"\x7fELF\x02\x01", f"Not little-endian ELF64: {label}")
    require(struct.unpack_from("<H", header, 18)[0] == ARCHES[arch][0], f"Wrong ELF architecture: {label} (expected {arch})")


def digest(path, algorithm):
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def verify_bundle(bundle, arch):
    for name in ELFS:
        require((bundle / name).is_file(), f"Missing bundle file: {name}")
    for path in [bundle / "atyaf", *sorted((bundle / "lib").glob("*.so"))]:
        with path.open("rb") as stream:
            elf_header(stream.read(20), arch, str(path))


def verify_zsync(image, control):
    with control.open("rb") as stream:
        data = stream.read(65536)
    header, separator, _ = data.partition(b"\n\n")
    require(separator, "Missing zsync header terminator")
    fields = dict(line.split(": ", 1) for line in header.decode("ascii").splitlines() if ": " in line)
    require(fields.get("zsync", "").startswith("0."), "Invalid zsync format")
    require(fields.get("Filename") == image.name, "zsync filename does not match AppImage")
    require(fields.get("URL", "").endswith("/" + image.name), "zsync URL does not match AppImage")
    require(int(fields.get("Length", "-1")) == image.stat().st_size, "zsync length does not match AppImage")
    require(fields.get("SHA-1") == digest(image, "sha1"), "zsync hash does not match AppImage")


def archive_member_names(path):
    names = {}
    for name in run("bsdtar", "-tf", str(path)).decode().splitlines():
        normal = name
        while normal.startswith("./"):
            normal = normal[2:]
        require(normal not in names, f"Duplicate archive path: {normal}")
        names[normal] = name
    return names


def verify_archive(path, arch):
    if path.suffix == ".rpm":
        with tempfile.TemporaryDirectory(prefix="atyaf-rpm-check-") as temporary:
            require(run("rpm", "--dbpath", temporary + "/db", "-qp", "--qf", "%{ARCH}", str(path)).decode() == arch, "Wrong RPM architecture")
            payload = pathlib.Path(temporary) / "payload.cpio"
            payload.write_bytes(run("rpm2cpio", str(path)))
            verify_archive(payload, arch)
        return
    names = archive_member_names(path)
    for name in ELFS:
        key = "opt/atyaf/" + name
        require(key in names, f"Missing package payload: {key}")
        elf_header(run("bsdtar", "-xOf", str(path), names[key])[:20], arch, f"{path.name}:{key}")
    if path.name.endswith(".pkg.tar.zst"):
        require(".PKGINFO" in names, "Missing Arch metadata")
        info = run("bsdtar", "-xOf", str(path), names[".PKGINFO"]).decode().splitlines()
        require(f"arch = {arch}" in info, "Wrong Arch package architecture")


def verify_deb(path, arch):
    require(run("dpkg-deb", "-f", str(path), "Architecture").decode().strip() == ARCHES[arch][1], "Wrong Debian architecture")
    with tarfile.open(fileobj=io.BytesIO(run("dpkg-deb", "--fsys-tarfile", str(path)))) as archive:
        members = {name.removeprefix("./"): name for name in archive.getnames()}
        for name in ELFS:
            key = "opt/atyaf/" + name
            require(key in members, f"Missing Debian payload: {key}")
            stream = archive.extractfile(members[key])
            require(stream is not None, f"Not a regular payload: {key}")
            with stream:
                elf_header(stream.read(20), arch, f"{path.name}:{key}")


def verify_flatpak(path, arch, version):
    # Import into a disposable OSTree repository, never a user's installation.
    with tempfile.TemporaryDirectory(prefix="atyaf-release-check-") as temporary:
        repo = pathlib.Path(temporary) / "repo"
        run("ostree", f"--repo={repo}", "init", "--mode=archive-z2")
        run("flatpak", "build-import-bundle", str(repo), str(path.resolve()))
        ref = f"app/com.h.atyaf/{arch}/master"
        require(ref in run("ostree", f"--repo={repo}", "refs").decode().splitlines(), "Wrong Flatpak architecture/ref")
        for name in ELFS:
            elf_header(run("ostree", f"--repo={repo}", "cat", ref, "/files/lib/atyaf/" + name)[:20], arch, f"{path.name}:{name}")
        metadata = ET.fromstring(run("ostree", f"--repo={repo}", "cat", ref, "/files/share/metainfo/com.h.atyaf.metainfo.xml"))
        require(any(item.get("version") == version for item in metadata.findall("./releases/release")), "Wrong Flatpak release version")


def verify_release(directory, version, arches, write_checksums=False):
    files = []
    for arch in arches:
        require(arch in ARCHES, f"Unsupported Linux architecture: {arch}")
        base = f"atyaf-{version}-linux-{arch}"
        paths = {suffix: directory / f"{base}.{suffix}" for suffix in FORMATS}
        for path in paths.values():
            require(path.is_file() and path.stat().st_size > 0, f"Missing/empty release asset: {path}")
        with paths["AppImage"].open("rb") as stream:
            header = stream.read(20)
            elf_header(header, arch, str(paths["AppImage"]))
            require(header[8:11] == b"AI\x02", "Not a type-2 AppImage")
        verify_zsync(paths["AppImage"], paths["AppImage.zsync"])
        verify_deb(paths["deb"], arch)
        for suffix in ("rpm", "pkg.tar.zst", "tar.gz"):
            verify_archive(paths[suffix], arch)
        verify_flatpak(paths["flatpak"], arch, version)
        files.extend(paths.values())
        print(f"Verified seven {arch} assets (ELF64, package metadata, zsync and Flatpak).", flush=True)
    if write_checksums:
        (directory / "SHA256SUMS").write_text("".join(f"{digest(path, 'sha256')}  {path.name}\n" for path in sorted(files)), encoding="utf-8")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dist", type=pathlib.Path, default=pathlib.Path("dist"))
    parser.add_argument("--version")
    parser.add_argument("--arch", choices=ARCHES, action="append", required=True)
    parser.add_argument("--bundle", type=pathlib.Path)
    parser.add_argument("--write-checksums", action="store_true")
    args = parser.parse_args()
    if args.bundle:
        require(len(args.arch) == 1, "A bundle has exactly one architecture")
        verify_bundle(args.bundle, args.arch[0])
    else:
        require(args.version is not None, "--version is required for release assets")
        verify_release(args.dist, args.version, args.arch, args.write_checksums)


if __name__ == "__main__":
    main()
