#!/usr/bin/env python3
"""Manage explicit per-profile terminal launchers; never run a profile here."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

NAME = re.compile(r'^[a-z][a-z0-9._-]{0,63}$')
IDENTIFIER = re.compile(r'^[a-zA-Z0-9-]+$')
RESERVED = set('alias bg break builtin cd command continue declare dirs disown do done elif else enable esac eval exec exit export false fc fg fi for function getopts hash help history if in jobs kill let local logout popd printf pushd pwd read readonly return select set shift shopt source test then time times trap true type typeset ulimit umask unalias unset until wait while atyaf'.split())


class Failure(Exception):
    def __init__(self, code, detail):
        self.code, self.detail = code, str(detail)


def directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    info = os.fstat(fd)
    if info.st_uid != os.getuid() or info.st_mode & 0o022:
        os.close(fd)
        raise Failure('unsafe', path)
    return fd


def read_file(fd, name, limit):
    handle = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
    with os.fdopen(handle, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or
                info.st_nlink != 1 or info.st_mode & 0o022 or info.st_size > limit):
            raise Failure('unsafe', name)
        data = stream.read(limit + 1)
        if len(data) > limit:
            raise Failure('unsafe', name)
        return data


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manage(request):
    root = os.path.abspath(request['root'])
    profile = request['profile']
    if not IDENTIFIER.fullmatch(profile) or not os.path.isabs(request['home']):
        raise Failure('invalid', profile)
    name = request.get('name', '')
    operation = request['operation']
    if operation == 'create' and (not NAME.fullmatch(name) or name in RESERVED):
        raise Failure('invalid', name)
    home = str(Path(request['home']).resolve(strict=True))
    bin_path = os.path.join(home, '.local', 'bin')
    root_fd = directory(root)
    lock = None
    bin_fd = None
    try:
        lock = os.open('terminal-commands.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600, dir_fd=root_fd)
        info = os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
            raise Failure('unsafe', 'terminal-commands.lock')
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            registry = json.loads(read_file(root_fd, 'terminal-commands.json', 1024 * 1024))
        except FileNotFoundError:
            registry = {}
        if not isinstance(registry, dict) or len(registry) > 1000:
            raise Failure('unsafe', 'terminal-commands.json')
        for key, value in registry.items():
            if (not NAME.fullmatch(key) or not isinstance(value, dict) or
                    not IDENTIFIER.fullmatch(value.get('profile', '')) or
                    not re.fullmatch(r'[0-9a-f]{64}', value.get('sha256', ''))):
                raise Failure('unsafe', 'terminal-commands.json')
        in_path = any(os.path.isabs(path) and os.path.realpath(path) == bin_path
                      for path in request.get('path', '').split(':'))
        def result(command):
            return {'name': command, 'path': os.path.join(bin_path, command), 'inPath': in_path}
        selected = [key for key, value in registry.items() if value['profile'] == profile]
        if operation == 'list':
            return [result(key) for key in sorted(selected)]
        if operation not in ('create', 'remove'):
            raise Failure('invalid', operation)
        if operation == 'remove' and not selected:
            return []
        home_fd = directory(home)
        local_fd = None
        try:
            try:
                os.mkdir('.local', 0o700, dir_fd=home_fd)
            except FileExistsError:
                pass
            local_fd = os.open('.local', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=home_fd)
            info = os.fstat(local_fd)
            if info.st_uid != os.getuid() or info.st_mode & 0o022:
                raise Failure('unsafe', '.local')
            try:
                os.mkdir('bin', 0o700, dir_fd=local_fd)
            except FileExistsError:
                pass
            bin_fd = os.open('bin', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=local_fd)
            info = os.fstat(bin_fd)
            if info.st_uid != os.getuid() or info.st_mode & 0o022:
                raise Failure('unsafe', bin_path)
        finally:
            if local_fd is not None:
                os.close(local_fd)
            os.close(home_fd)

        def save_registry():
            descriptor, temporary = tempfile.mkstemp(prefix='.terminal-commands-', dir=root)
            try:
                with os.fdopen(descriptor, 'wb') as stream:
                    stream.write(json.dumps(registry, ensure_ascii=False).encode())
                    stream.flush()
                    os.fsync(stream.fileno())
                os.replace(temporary, 'terminal-commands.json', dst_dir_fd=root_fd)
            finally:
                if os.path.lexists(temporary):
                    os.unlink(temporary)

        def owned(command):
            record = registry.get(command)
            if not record or record['profile'] != profile:
                return False
            try:
                return digest(read_file(bin_fd, command, 65536)) == record['sha256']
            except (OSError, Failure):
                return False

        if operation == 'remove':
            preserved = []
            for command in selected:
                try:
                    os.stat(command, dir_fd=bin_fd, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    if owned(command):
                        os.unlink(command, dir_fd=bin_fd)
                    else:
                        preserved.append(command)
                del registry[command]
            save_registry()
            return preserved

        record = registry.get(name)
        if record and record['profile'] != profile:
            raise Failure('conflict', name)
        exists = False
        try:
            os.stat(name, dir_fd=bin_fd, follow_symlinks=False)
            exists = True
        except FileNotFoundError:
            pass
        if exists and not owned(name):
            raise Failure('conflict', os.path.join(bin_path, name))
        # Refuse all other PATH matches, even if the new directory precedes one.
        for path in request.get('path', '').split(':'):
            candidate = os.path.join(path or '.', name)
            if os.path.realpath(path or '.') == bin_path:
                continue
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                raise Failure('conflict', candidate)
        launcher = request['launcher']
        if (not isinstance(launcher, list) or not launcher or
                not all(isinstance(item, str) and '\x00' not in item for item in launcher) or
                not os.path.isabs(launcher[0]) or not os.access(launcher[0], os.X_OK)):
            raise Failure('unsafe', 'Atyaf launcher is unavailable')
        if len(registry) >= 1000 and name not in registry:
            raise Failure('unsafe', 'Terminal command count limit exceeded')
        script = ('#!/usr/bin/python3\n# Atyaf profile terminal command v1\n'
                  'import os,sys\n'
                  'if len(sys.argv) != 1:\n'
                  '    sys.stderr.write(' + repr(request['argumentsWarning'] + '\n') + ')\n'
                  '    sys.exit(64)\n'
                  'os.environ["HOME"] = ' + repr(home) + '\n'
                  'os.environ["XDG_DATA_HOME"] = ' + repr(request['dataHome']) + '\n'
                  'os.execv(' + repr(launcher[0]) + ', ' + repr(launcher + ['--launch-profile', profile]) + ')\n').encode()
        if len(script) > 65536:
            raise Failure('unsafe', 'Terminal command exceeds size limit')
        previous = read_file(bin_fd, name, 65536) if exists else None
        descriptor, temporary = tempfile.mkstemp(prefix='.atyaf-command-', dir=bin_path)
        published = False
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(script)
                os.fchmod(stream.fileno(), 0o700)
                stream.flush()
                os.fsync(stream.fileno())
            if exists:
                if not owned(name):
                    raise Failure('conflict', name)
                os.replace(temporary, name, dst_dir_fd=bin_fd)
            else:
                # Exclusive publication never overwrites a racing external file.
                os.link(temporary, name, dst_dir_fd=bin_fd, follow_symlinks=False)
                os.unlink(temporary)
            published = True
            registry[name] = {'profile': profile, 'sha256': digest(script)}
            save_registry()
        except BaseException:
            if published:
                if previous is None:
                    os.unlink(name, dir_fd=bin_fd)
                else:
                    with open(temporary, 'xb') as stream:
                        stream.write(previous)
                        os.fchmod(stream.fileno(), 0o700)
                    os.replace(temporary, name, dst_dir_fd=bin_fd)
            raise
        finally:
            if os.path.lexists(temporary):
                os.unlink(temporary)
        return result(name)
    finally:
        if bin_fd is not None:
            os.close(bin_fd)
        if lock is not None:
            os.close(lock)
        os.close(root_fd)


if __name__ == '__main__':
    os.umask(0o077)
    try:
        print(json.dumps({'ok': manage(json.loads(sys.argv[1]))}, ensure_ascii=False))
    except Failure as error:
        print(json.dumps({'error': error.code, 'detail': error.detail}, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({'error': 'unsafe', 'detail': str(error)}, ensure_ascii=False))
