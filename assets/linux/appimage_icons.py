#!/usr/bin/env python3
"""Read AppImage icon members through 7-Zip stdout; never execute/mount an image.

No archive pathname is used as a host output path. Links are resolved only in
an in-memory member table. Only bounded, decoded PNG copies leave temporary
storage. 7-Zip handles SquashFS/ISO image offsets without invoking AppRun.
"""
import base64
import configparser
import os
from pathlib import Path, PurePosixPath
import posixpath
import resource
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import json

from desktop_icon_helper import IMAGE_EXTENSIONS, install, valid

MAX_IMAGE = 16 * 1024 * 1024
MAX_TOTAL = 64 * 1024 * 1024
MAX_CANDIDATES = 32


def child_limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2, 512 * 1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_NOFILE, (64, 64))


def capture(arguments, limit, deadline):
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               start_new_session=True, preexec_fn=child_limits,
                               env={**os.environ, 'LC_ALL': 'C.UTF-8'})
    output = bytearray()
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise ValueError('AppImage icon reader timed out')
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    break
                output.extend(chunk)
                if len(output) > limit:
                    raise ValueError('AppImage icon reader output exceeds limit')
        if process.wait(timeout=max(0.01, deadline - time.monotonic())) != 0:
            raise ValueError('AppImage icon member could not be read')
        return bytes(output)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        process.stdout.close()


def member_name(name):
    path = PurePosixPath(name)
    if (not name or len(name) > 4096 or path.is_absolute() or
            '..' in path.parts or '\\' in name or
            any(ord(char) < 32 for char in name)):
        raise ValueError('Unsafe AppImage member path')
    return str(path)


class ImageReader:
    def __init__(self, tool, image):
        self.command = [tool]
        self.image = str(image)
        self.deadline = time.monotonic() + 45
        listing = capture(self.command + ['l', '-slt', '-sccUTF-8', '--', self.image],
                          16 * 1024**2, self.deadline).decode('utf-8', errors='strict')
        header, separator, body = listing.partition('\n----------\n')
        if not separator or not any('\nType = ' + kind + '\n' in header for kind in ['SquashFS', 'Iso']):
            raise NotImplementedError('Unsupported AppImage filesystem')
        self.members = {}
        for block in body.strip().split('\n\n'):
            fields = dict(line.split(' = ', 1) for line in block.splitlines() if ' = ' in line)
            if 'Path' not in fields:
                continue
            name = member_name(fields['Path'])
            if name in self.members:
                raise ValueError('Duplicate AppImage member')
            self.members[name] = fields
            if len(self.members) > 100000:
                raise ValueError('AppImage member limit exceeded')
        self.cache = {}
        self.total = 0

    def read(self, name, limit=MAX_IMAGE, seen=()):
        name = member_name(name)
        if name in seen or len(seen) >= 16:
            raise ValueError('Cyclic AppImage icon link')
        fields = self.members.get(name)
        if not fields or fields.get('Folder') == '+':
            return None
        mode = fields.get('Mode', '-')
        if mode[:1] not in ('-', 'l'):
            return None
        size = int(fields.get('Size') or 0)
        link = fields.get('Symbolic Link')
        is_link = mode.startswith('l') or bool(link)
        if link:
            if len(link.encode('utf-8')) > 4096:
                return None
            data = link.encode('utf-8')
        else:
            if not 0 < size <= (4096 if is_link else limit):
                return None
            if name not in self.cache:
                data = capture(self.command + ['x', '-so', '-spd', '-r-', '-sccUTF-8', '--', self.image, name],
                               min(limit, 4096) if is_link else limit, self.deadline)
                self.total += len(data)
                if self.total > MAX_TOTAL:
                    raise ValueError('AppImage icon byte limit exceeded')
                self.cache[name] = data
            data = self.cache[name]
        if is_link:
            target = data.decode('utf-8', errors='strict')
            # Absolute targets are archive-root relative, never host paths.
            target = posixpath.normpath(target.lstrip('/') if target.startswith('/')
                                        else posixpath.join(posixpath.dirname(name), target))
            return self.read(member_name(target), limit, (*seen, name))
        return data if len(data) <= limit else None

    def candidates(self):
        names = sorted(self.members)
        icons = []
        if '.DirIcon' in self.members:
            icons.append('.DirIcon')
        desktops = [name for name in names if name.endswith('.desktop') and
                    ('/' not in name or name.startswith('usr/share/applications/'))]
        for name in desktops[:16]:
            try:
                data = self.read(name, 64 * 1024)
                if not data:
                    continue
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.read_string(data.decode('utf-8'))
                icon = parser.get('Desktop Entry', 'Icon', fallback='')
                if not icon or len(icon) > 4096:
                    continue
                stem = PurePosixPath(icon).stem
                matches = [candidate for candidate in names if
                           PurePosixPath(candidate).stem == stem and
                           PurePosixPath(candidate).suffix.lower() in IMAGE_EXTENSIONS and
                           ('/' not in candidate or candidate.startswith(('usr/share/icons/', 'usr/share/pixmaps/')))]
                icons.extend(sorted(matches, key=lambda item: ('256' not in item, '512' not in item, item)))
            except (ValueError, UnicodeError, configparser.Error):
                continue
        icons.extend(name for name in names if '/' not in name and PurePosixPath(name).suffix.lower() in IMAGE_EXTENSIONS)
        icons.extend(name for name in names if name.startswith(('usr/share/icons/', 'usr/share/pixmaps/')) and
                     PurePosixPath(name).suffix.lower() in IMAGE_EXTENSIONS)
        return list(dict.fromkeys(icons))[:MAX_CANDIDATES]


def extract_icons(root):
    root = Path(root)
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise ValueError('AppImage icon destination must be a private application directory')
    image = root / 'application.AppImage'
    if image.is_symlink() or not image.is_file():
        raise ValueError('AppImage must be a regular managed file')
    tool = shutil.which('7zz') or shutil.which('7z')
    if not tool:
        return {'status': 'missing_tool'}
    try:
        reader = ImageReader(tool, image)
    except NotImplementedError:
        return {'status': 'unsupported'}
    except (OSError, ValueError, subprocess.SubprocessError):
        return {'status': 'unavailable'}
    destination = root / '.appimage-icons'
    # Never overwrite/follow pre-existing links or files in a caller's tree.
    if os.path.lexists(destination) or os.path.lexists(root / '.DirIcon'):
        raise ValueError('AppImage icon destination already exists')
    result = []
    with tempfile.TemporaryDirectory(prefix='.appimage-icons-', dir=root) as temporary:
        prepared = Path(temporary) / 'prepared'
        prepared.mkdir(mode=0o700)
        raw = Path(temporary) / 'source'
        for index, name in enumerate(reader.candidates()):
            try:
                data = reader.read(name)
                if not data:
                    continue
                raw.write_bytes(data)
                if not valid(raw):
                    continue
                basename = PurePosixPath(name).stem
                output = prepared / (str(index) + '-' + basename + '.png')
                install(str(output), [str(raw)])
                result.append(output.name)
            except (OSError, ValueError, UnicodeError, subprocess.SubprocessError):
                continue
        if not result:
            return {'status': 'no_icon'}
        # An independent normalized PNG is used by existing automatic shortcuts.
        primary = (prepared / result[0]).read_bytes()
        os.rename(prepared, destination)
        try:
            with open(root / '.DirIcon', 'xb') as output:
                output.write(primary)
            os.chmod(root / '.DirIcon', 0o600)
        except BaseException:
            shutil.rmtree(destination)
            raise
    return {'status': 'ready', 'icon': base64.b64encode(primary).decode('ascii')}


if __name__ == '__main__':
    os.umask(0o077)
    try:
        print(json.dumps(extract_icons(sys.argv[1])))
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
