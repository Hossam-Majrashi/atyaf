#!/usr/bin/env python3
"""Manage only explicitly registered Atyaf session-start entries, without launch."""
import fcntl
import hashlib
import json
import os
import re
import stat
import sys

from terminal_commands import Failure, directory, read_file, digest


def private_tree(path):
    if not os.path.isabs(path) or os.path.realpath(path) != path:
        raise Failure('unsafe', 'Noncanonical autostart directory')
    # Traverse without following links, including racing parent substitutions.
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.strip('/').split('/'):
            try:
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            except FileNotFoundError:
                os.mkdir(part, 0o700, dir_fd=fd)
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise Failure('unsafe', path)
        return fd
    except BaseException:
        os.close(fd)
        raise


def manage(request):
    root, config, profile = request['root'], request['config'], request['profile']
    if (not os.path.isabs(root) or os.path.realpath(root) != root or
            not re.fullmatch(r'[A-Za-z0-9-]{1,80}', profile)):
        raise Failure('invalid', profile)
    operation = request['operation']
    if operation not in ('status', 'enable', 'disable'):
        raise Failure('invalid', operation)
    filename = 'com.h.atyaf.' + hashlib.sha256(root.encode()).hexdigest()[:16] + '.profile-' + profile + '.desktop'
    root_fd = directory(root)
    lock, config_fd, target_fd = None, None, None
    temporary = None
    try:
        lock = os.open('autostart.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600, dir_fd=root_fd)
        info = os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1 or info.st_mode & 0o022:
            raise Failure('unsafe', 'autostart.lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            registry = json.loads(read_file(root_fd, 'autostart.json', 1024 * 1024))
        except FileNotFoundError:
            registry = {}
        if not isinstance(registry, dict) or len(registry) > 1000:
            raise Failure('unsafe', 'autostart.json')
        for key, value in registry.items():
            if not re.fullmatch(r'[A-Za-z0-9-]{1,80}', key) or not isinstance(value, str) or not re.fullmatch(r'[0-9a-f]{64}', value):
                raise Failure('unsafe', 'autostart.json')
        # Validate the config parent as well as the autostart directory.
        config_fd = private_tree(config)
        try:
            os.mkdir('autostart', 0o700, dir_fd=config_fd)
        except FileExistsError:
            pass
        target_fd = os.open('autostart', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=config_fd)
        info = os.fstat(target_fd)
        if info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise Failure('unsafe', 'autostart')
        try:
            previous = read_file(target_fd, filename, 65536)
        except FileNotFoundError:
            previous = None
        expected = registry.get(profile)
        if previous is not None and (expected is None or digest(previous) != expected):
            raise Failure('conflict', 'Existing or modified autostart entry preserved')
        if operation == 'status':
            return previous is not None
        if operation == 'disable' and previous is None and expected is None:
            return False
        content = request.get('content', '').encode()
        if operation == 'enable' and (not content or len(content) > 65536 or (len(registry) >= 1000 and profile not in registry)):
            raise Failure('invalid', 'Autostart entry size/count')

        def same_target():
            try:
                current = read_file(target_fd, filename, 65536)
            except FileNotFoundError:
                current = None
            if current != previous:
                raise Failure('conflict', 'Autostart changed concurrently')

        # Stage registry before changing external integration.
        updated = dict(registry)
        if operation == 'enable':
            updated[profile] = digest(content)
        else:
            updated.pop(profile, None)
        registry_name = '.autostart-registry-' + os.urandom(12).hex()
        registry_fd = os.open(registry_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=root_fd)
        changed = False
        try:
            with os.fdopen(registry_fd, 'wb') as stream:
                stream.write(json.dumps(updated).encode())
                stream.flush()
                os.fsync(stream.fileno())
            same_target()
            if operation == 'enable':
                temporary = '.atyaf-autostart-' + os.urandom(12).hex()
                descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=target_fd)
                with os.fdopen(descriptor, 'wb') as stream:
                    stream.write(content)
                    stream.flush()
                    os.fsync(stream.fileno())
                same_target()
                if previous is None:
                    os.link(temporary, filename, src_dir_fd=target_fd, dst_dir_fd=target_fd, follow_symlinks=False)
                    os.unlink(temporary, dir_fd=target_fd)
                else:
                    os.replace(temporary, filename, src_dir_fd=target_fd, dst_dir_fd=target_fd)
                temporary = None
            elif previous is not None:
                os.unlink(filename, dir_fd=target_fd)
            changed = True
            os.replace(registry_name, 'autostart.json', src_dir_fd=root_fd, dst_dir_fd=root_fd)
        except BaseException:
            if changed:
                # Restore only the integration just published, never a changed file.
                if operation == 'enable':
                    if read_file(target_fd, filename, 65536) != content:
                        raise Failure('conflict', 'Autostart changed during rollback')
                    os.unlink(filename, dir_fd=target_fd)
                if previous is not None:
                    restore_fd = os.open(filename, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=target_fd)
                    with os.fdopen(restore_fd, 'wb') as stream:
                        stream.write(previous)
                        stream.flush()
                        os.fsync(stream.fileno())
            raise
        finally:
            try:
                os.unlink(registry_name, dir_fd=root_fd)
            except FileNotFoundError:
                pass
        return operation == 'enable'
    finally:
        if temporary is not None:
            os.unlink(temporary, dir_fd=target_fd)
        for fd in (target_fd, config_fd, lock, root_fd):
            if fd is not None:
                os.close(fd)


if __name__ == '__main__':
    os.umask(0o077)
    try:
        print(json.dumps({'ok': manage(json.loads(sys.argv[1]))}))
    except Exception as error:
        print(json.dumps({'error': str(error)}))
