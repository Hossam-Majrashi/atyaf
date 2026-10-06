#!/usr/bin/env python3
"""Trusted host bridge for Flatpak; argv and environment never enter a shell."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import tempfile


def identity(pid):
    try:
        stat = Path(f'/proc/{pid}/stat').read_text()
        fields = stat[stat.rfind(')') + 2:].split()
        if fields[0] == 'Z':
            return None
        return Path('/proc/sys/kernel/random/boot_id').read_text().strip() + ':' + fields[19]
    except OSError:
        return None


def write(path, value):
    with tempfile.NamedTemporaryFile(mode='w', dir=Path(path).parent, delete=False) as temporary:
        json.dump(value, temporary)
        temporary.flush()
        os.fsync(temporary.fileno())
    try:
        os.replace(temporary.name, path)
    finally:
        if os.path.exists(temporary.name):
            os.unlink(temporary.name)


def launch(request_path):
    request = json.loads(Path(request_path).read_text())
    if os.getuid() == 0:
        raise ValueError('Launching as root is prohibited')
    child = subprocess.Popen([request['executable']] + request['arguments'],
                             cwd=request['workingDirectory'], env=request['environment'],
                             stdin=subprocess.DEVNULL, start_new_session=True)
    state = {'pid': child.pid, 'identity': identity(child.pid), 'running': True, 'heartbeat': time.time()}
    try:
        while child.poll() is None:
            state['heartbeat'] = time.time()
            write(request['status'], state)
            time.sleep(0.2)
        state.update(running=False, exitCode=child.returncode, heartbeat=time.time())
        write(request['status'], state)
        return child.returncode if child.returncode >= 0 else 128 - child.returncode
    finally:
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)


def main():
    if sys.argv[1] == 'launch':
        return launch(sys.argv[2])
    if sys.argv[1] == 'signal':
        pid = int(sys.argv[2])
        if identity(pid) != sys.argv[3]:
            raise ValueError('Process identity changed')
        os.killpg(pid, signal.SIGKILL if sys.argv[4] == 'force' else signal.SIGTERM)
        return 0
    raise ValueError('Invalid operation')


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
