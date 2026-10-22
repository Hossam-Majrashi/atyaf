#!/usr/bin/env python3
"""Bounded extraction with deferred confined links; never executes archive contents."""
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile

LIMIT = 8 * 1024**3
COUNT = 100000


def clean_name(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name or any(ord(c) < 32 for c in name):
        raise ValueError('Unsafe archive path: ' + name)
    if len(name) > 4096:
        raise ValueError('Archive path too long')
    return path


def extract(source, destination):
    root = Path(destination).resolve()
    root.mkdir(mode=0o700, parents=True, exist_ok=False)
    temporary = None
    try:
        if source.endswith('.tar.zst'):
            temporary = tempfile.TemporaryFile()
            proc = subprocess.Popen(['zstd', '-dc', '--', source], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            total = 0
            try:
                while True:
                    chunk = proc.stdout.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > LIMIT:
                        raise ValueError('Decompressed archive exceeds limit')
                    temporary.write(chunk)
                if proc.wait() != 0:
                    raise ValueError('Zstandard decompression failed')
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                proc.stdout.close()
            temporary.seek(0)
        with tarfile.open(source if temporary is None else None, fileobj=temporary, mode='r:*') as archive:
            members = []
            total = 0
            names = set()
            links = {}
            for member in archive:
                name = clean_name(member.name)
                if str(name) == '.':
                    if not member.isdir():
                        raise ValueError('Invalid archive root')
                    continue
                if str(name) in names:
                    raise ValueError('Duplicate archive member')
                names.add(str(name))
                if not (member.isfile() or member.isdir() or member.issym()):
                    raise ValueError('Unsupported special file or hard link')
                if member.issym():
                    target = member.linkname
                    if not target or len(target) > 4096 or '\\' in target or any(ord(c) < 32 for c in target):
                        raise ValueError('Unsafe symlink: ' + str(name) + ' -> ' + repr(target))
                    if PurePosixPath(target).is_absolute():
                        # Distribution-layout packages may link usr/bin/app to
                        # /opt/app/launcher. Rebase into this archive, never the
                        # host filesystem; final strict checks require a target
                        # extracted here and validate the complete link chain.
                        internal = clean_name(target.lstrip('/'))
                        target = os.path.relpath(root / str(internal), root / str(name.parent))
                    resolved = (root / str(name.parent) / target).resolve()
                    if not resolved.is_relative_to(root):
                        raise ValueError('Symlink escapes destination: ' + str(name))
                    links[name] = target
                if member.size < 0:
                    raise ValueError('Negative member size')
                total += member.size
                if total > LIMIT or len(names) > COUNT:
                    raise ValueError('Archive resource limit exceeded')
                members.append((member, name))
            for member, name in members:
                if any(parent in links for parent in name.parents):
                    raise ValueError('Archive writes through symlink')
                out = root / str(name)
                if member.isdir():
                    out.mkdir(mode=0o700, parents=True, exist_ok=True)
                elif member.isfile():
                    out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    with archive.extractfile(member) as inp, open(out, 'xb') as output:
                        shutil.copyfileobj(inp, output, 1024 * 1024)
                    os.chmod(out, (member.mode & 0o755) | 0o600)
            for member, name in members:
                if member.issym():
                    out = root / str(name)
                    out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    os.symlink(links[name], out)
            for link in links:
                try:
                    resolved = (root / str(link)).resolve(strict=True)
                except (OSError, RuntimeError) as error:
                    raise ValueError('Missing or cyclic archive symlink: ' + str(link)) from error
                if not resolved.is_relative_to(root):
                    raise ValueError('Symlink chain escapes destination: ' + str(link))
    except BaseException:
        shutil.rmtree(root)
        raise
    finally:
        if temporary:
            temporary.close()


def copy_folder(source, destination):
    source = Path(source).resolve(strict=True)
    root = Path(destination).absolute()
    if not source.is_dir() or root.resolve().is_relative_to(source):
        raise ValueError('Source must be a separate application directory')
    root.mkdir(mode=0o700, parents=True, exist_ok=False)
    total = 0
    count = 0
    links = []
    def walk_error(error):
        raise error
    try:
        for current, directories, files in os.walk(source, followlinks=False, onerror=walk_error):
            if not Path(current).resolve(strict=True).is_relative_to(source):
                raise ValueError('Source directory changed during copy')
            for name in directories + files:
                inp = Path(current) / name
                relative = inp.relative_to(source)
                clean_name(str(relative))
                out = root / relative
                info = inp.lstat()
                count += 1
                if count > COUNT:
                    raise ValueError('Folder member limit exceeded')
                if stat.S_ISLNK(info.st_mode):
                    target = inp.resolve(strict=True)
                    if not target.is_relative_to(source):
                        raise ValueError('Folder symlink escapes source')
                    links.append((out, os.path.relpath(root / target.relative_to(source), out.parent)))
                elif stat.S_ISDIR(info.st_mode):
                    out.mkdir(mode=0o700, parents=True, exist_ok=True)
                elif stat.S_ISREG(info.st_mode):
                    out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    with os.fdopen(os.open(inp, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as stream, open(out, 'xb') as output:
                        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                            raise ValueError('Source file changed type')
                        while True:
                            chunk = stream.read(1024 * 1024)
                            if not chunk:
                                break
                            total += len(chunk)
                            if total > LIMIT:
                                raise ValueError('Folder size limit exceeded')
                            output.write(chunk)
                    os.chmod(out, (info.st_mode & 0o755) | 0o600)
                else:
                    raise ValueError('Unsupported special file in folder')
        for out, target in links:
            out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            os.symlink(target, out)
        for out, _ in links:
            if not out.resolve(strict=True).is_relative_to(root.resolve()):
                raise ValueError('Copied symlink escapes destination')
    except BaseException:
        shutil.rmtree(root)
        raise


def copy_executable(source, destination, appimage=False):
    """Copy one regular executable as data; never run it or its runtime."""
    root = Path(destination).absolute()
    name = 'application.AppImage' if appimage else Path(source).name
    if str(clean_name(name)) in ('', '.'):
        raise ValueError('Invalid executable filename')
    # O_NONBLOCK prevents a selected FIFO/device from blocking before fstat.
    fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o6000:
            raise ValueError('Executable must be a regular, non-privileged file')
        if info.st_size < (64 if appimage else 1) or info.st_size > LIMIT:
            raise ValueError('Executable size outside import limits')
        if not appimage and not info.st_mode & 0o111:
            raise ValueError('Source must have executable permission')
        if appimage:
            header = stream.read(64)
            if (header[:7] != b'\x7fELF\x02\x01\x01' or
                    header[8:11] not in (b'AI\x01', b'AI\x02') or
                    struct.unpack_from('<H', header, 16)[0] not in (2, 3) or
                    struct.unpack_from('<H', header, 18)[0] not in (62, 183)):
                raise ValueError('Invalid x64/ARM64 AppImage header')
        root.mkdir(mode=0o700, parents=True, exist_ok=False)
        try:
            stream.seek(0)
            total = 0
            with open(root / name, 'xb') as output:
                while True:
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > LIMIT:
                        raise ValueError('Executable size limit exceeded')
                    output.write(chunk)
            after = os.fstat(stream.fileno())
            if (total != info.st_size or
                    (after.st_size, after.st_mtime_ns, after.st_ctime_ns) !=
                    (info.st_size, info.st_mtime_ns, info.st_ctime_ns)):
                raise ValueError('Executable changed during copy')
            # Only the independent managed copy receives executable permission.
            os.chmod(root / name, 0o700)
        except BaseException:
            shutil.rmtree(root)
            raise


def backup(root, snapshot, output):
    root = Path(root).resolve()
    def safe(info):
        if info.islnk():
            raise ValueError('Hard links are not supported in backups')
        if info.issym():
            target = (root / str(PurePosixPath(info.name).parent) / info.linkname).resolve()
            if os.path.isabs(info.linkname) or not target.is_relative_to(root):
                raise ValueError('External symlinks are not included in backups')
        if not (info.isdir() or info.isfile() or info.issym()):
            return None
        return info
    with os.fdopen(os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as stream, tarfile.open(fileobj=stream, mode='w:gz', dereference=False) as archive:
        archive.add(snapshot, arcname='library.sqlite')
        metadata = json.dumps({'format': 1, 'root': str(root)}).encode()
        import io
        info = tarfile.TarInfo('backup.json')
        info.size = len(metadata)
        info.mode = 0o600
        archive.addfile(info, io.BytesIO(metadata))
        for directory in ['profiles', 'portable', 'applications']:
            if (root / directory).exists():
                archive.add(root / directory, arcname=directory, filter=safe)


def main():
    os.umask(0o077)
    if sys.argv[1] == 'extract' and len(sys.argv) == 4:
        extract(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'copy' and len(sys.argv) == 4:
        copy_folder(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'appimage' and len(sys.argv) == 4:
        copy_executable(sys.argv[2], sys.argv[3], appimage=True)
    elif sys.argv[1] == 'executable' and len(sys.argv) == 4:
        copy_executable(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'backup' and len(sys.argv) == 5:
        backup(*sys.argv[2:])
    else:
        raise ValueError('Invalid operation')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
