#!/usr/bin/python3
"""Associate only an identity-checked profile's windows on KDE, without rules.

KWin supplies the actual Wayland/X11 class for StartupWMClass, not a guessed
application name. Temporary activation scripts never change compositor rules.
"""
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid


def identity(pid):
    try:
        directory = Path('/proc') / str(pid)
        if directory.stat().st_uid != os.getuid():
            return None
        fields = (directory / 'stat').read_text().rsplit(') ', 1)[1].split()
        if fields[0] == 'Z':
            return None
        boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
        return boot + ':' + fields[19]
    except (OSError, ValueError, IndexError):
        return None


def descendants(pid):
    """Read only children of the verified process, bounded against fork storms."""
    result = {pid}
    pending = [pid]
    while pending and len(result) < 512:
        parent = pending.pop()
        try:
            tasks = list((Path('/proc') / str(parent) / 'task').iterdir())[:512]
            for task in tasks:
                for child in (task / 'children').read_text().split():
                    child = int(child)
                    if child not in result and identity(child) is not None:
                        result.add(child)
                        pending.append(child)
                    if len(result) >= 512:
                        break
        except (OSError, ValueError):
            continue
    return sorted(result)


def call(destination, path, method, *arguments):
    result = subprocess.run(
        ['gdbus', 'call', '--session', '--dest', destination,
         '--object-path', path, '--method', method, *arguments],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        text=True, timeout=2, check=True)
    if len(result.stdout) > 1024 * 1024:
        raise ValueError('Desktop response exceeds limit')
    return result.stdout


def kwin(method, *arguments):
    return call('org.kde.KWin', '/Scripting',
                'org.kde.kwin.Scripting.' + method, *arguments)


def script(pids, activate):
    return '''const pids = new Set(%s);
const activate = %s;
function associate(window) {
    if (!pids.has(window.pid) || window.deleted ||
        window.specialWindow || window.popupWindow) return;
    if (activate) {
        window.minimized = false;
        workspace.activeWindow = window;
    }
}
workspace.windowList().forEach(associate);
workspace.windowAdded.connect(associate);
''' % (json.dumps(pids), json.dumps(activate))


def notify_single_instance(pids):
    """Tauri's tray-only windows may need its existing single-instance callback.

    Only a well-known callback owned by this exact process tree is invoked.
    No global bus owner is inferred from the application name or shortcut.
    """
    names = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                 'org.freedesktop.DBus.ListNames')
    deadline = time.monotonic() + 3
    for name in re.findall(r"'([A-Za-z_][A-Za-z0-9_.]*\.SingleInstance)'", names)[:64]:
        if time.monotonic() >= deadline:
            return
        try:
            owner_name = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                              'org.freedesktop.DBus.GetNameOwner', name)
            unique = re.fullmatch(r"\('(:[0-9]+\.[0-9]+)',\)\s*", owner_name)
            if not unique:
                continue
            owner = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                         'org.freedesktop.DBus.GetConnectionUnixProcessID', unique[1])
            match = re.fullmatch(r'\(uint32 (\d+),\)\s*', owner)
            if not match or int(match[1]) not in pids:
                continue
            # Address the verified connection, not a reassignable bus name.
            call(unique[1], '/' + name.replace('.', '/'),
                 'org.SingleInstance.DBus.ExecuteCallback', '[]', '/')
        except (OSError, ValueError, subprocess.SubprocessError):
            continue


def window_classes(pids):
    result = call('org.kde.KWin', '/WindowsRunner',
                  'org.kde.krunner1.Match', 'windows')
    # Match IDs contain only UUIDs. Never evaluate GVariant text or window
    # titles, which can contain arbitrary application/user data.
    ids = re.findall(r"['\"]0_(\{[0-9a-f-]{36}\})['\"]", result)
    deadline = time.monotonic() + 3
    for window_id in ids[:512]:
        if time.monotonic() >= deadline:
            return
        info = call('org.kde.KWin', '/KWin',
                    'org.kde.KWin.getWindowInfo', window_id)
        owner = re.search(r"'pid': <(?:u?int32 )?(\d+)>", info)
        wm_class = re.search(r"'resourceClass': <'([A-Za-z0-9_.-]{1,200})'>", info)
        if owner and int(owner[1]) in pids and wm_class:
            yield wm_class[1]


def refresh_shortcut(desktop, wm_class=None):
    """Change only missing managed integration fields; retain explicit classes."""
    parent = desktop.parent
    parent_info = parent.stat()
    if parent_info.st_uid != os.getuid() or parent_info.st_mode & 0o022:
        return
    fd = os.open(desktop, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(fd)
        if (not stat.S_ISREG(before.st_mode) or before.st_uid != os.getuid() or
                before.st_nlink != 1 or before.st_size > 65536):
            return
        content = os.read(fd, 65537).decode('utf-8')
    finally:
        os.close(fd)
    profile_id = desktop.stem.removeprefix('com.h.atyaf.profile-')
    if (not content.startswith('[Desktop Entry]\n') or
            not any(line.startswith('Exec=') and '--launch-profile' in line and
                    profile_id in line for line in content.splitlines())):
        return
    lines = content.splitlines()
    if not any(line.startswith('StartupNotify=') for line in lines):
        lines.insert(1, 'StartupNotify=false')
    if wm_class and not any(line.startswith('StartupWMClass=') and
                            line.partition('=')[2] for line in lines):
        lines = [line for line in lines if not line.startswith(
            ('StartupWMClass=', 'X-Atyaf-AutomaticWMClass='))]
        lines.insert(1, 'StartupWMClass=' + wm_class)
        lines.insert(1, 'X-Atyaf-AutomaticWMClass=true')
    updated = '\n'.join(lines) + '\n'
    if updated == content:
        return
    with tempfile.TemporaryDirectory(prefix='.atyaf-window-', dir=parent) as temporary:
        staged = Path(temporary) / 'entry'
        staged.write_text(updated)
        staged.chmod(stat.S_IMODE(before.st_mode))
        current = desktop.lstat()
        if (current.st_ino, current.st_mtime_ns, current.st_size) != (
                before.st_ino, before.st_mtime_ns, before.st_size):
            return
        os.replace(staged, desktop)
    try:
        subprocess.run(['kbuildsycoca6'], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=5, check=False)
    except (OSError, subprocess.SubprocessError):
        pass


def update(request):
    pid = request['pid']
    expected = request['identity']
    desktop = Path(request['desktop'])
    activate = request['activate']
    if (type(pid) is not int or pid <= 1 or type(activate) is not bool or
            not isinstance(expected, str) or not desktop.is_absolute() or
            not re.fullmatch(r'com\.h\.atyaf\.profile-[A-Za-z0-9-]+\.desktop', desktop.name) or
            not desktop.is_file() or identity(pid) != expected):
        return
    refresh_shortcut(desktop)
    if not activate:
        deadline = time.monotonic() + 30
        while identity(pid) == expected and time.monotonic() < deadline:
            found = next(window_classes(descendants(pid)), None)
            if found:
                refresh_shortcut(desktop, found)
                return
            time.sleep(0.5)
        return
    plugin = 'atyaf-profile-' + uuid.uuid4().hex
    loaded = False
    with tempfile.TemporaryDirectory(prefix='atyaf-windows-') as directory:
        source = Path(directory) / 'associate.js'
        previous = None
        try:
            if activate:
                notify_single_instance(descendants(pid))
            # Catch a tray callback that creates its window asynchronously.
            # This is not a permanent rule or a shared-WM_CLASS focus match.
            deadline = time.monotonic() + 2
            while identity(pid) == expected and time.monotonic() < deadline:
                pids = descendants(pid)
                if pids != previous:
                    if loaded:
                        kwin('unloadScript', plugin)
                        loaded = False
                    source.write_text(script(pids, activate))
                    result = kwin('loadScript', str(source), plugin)
                    match = re.fullmatch(r'\((?:int32 )?(\d+),\)\s*', result)
                    if not match:
                        return
                    loaded = True
                    call('org.kde.KWin', '/Scripting/Script' + match[1],
                         'org.kde.kwin.Script.run')
                    previous = pids
                time.sleep(0.2)
        finally:
            if loaded:
                try:
                    kwin('unloadScript', plugin)
                except (OSError, ValueError, subprocess.SubprocessError):
                    pass


if __name__ == '__main__':
    try:
        update(json.loads(sys.argv[1]))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        # Missing/unsupported compositor tools are optional, not launch errors.
        pass
