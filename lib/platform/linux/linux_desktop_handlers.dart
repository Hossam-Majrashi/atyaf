import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'linux_commands.dart';

/// Desktop handlers run with the original host desktop environment, not profile XDG
/// paths. The private wrapper is also suitable for Electron's xdg-open calls.
final class LinuxDesktopHandlers {
  LinuxDesktopHandlers(this.directory, this.host);
  final String directory;
  final Map<String, String> host;
  String get opener => p.join(directory, 'xdg-open');

  // Do not persist arbitrary host tokens or pass profile secrets to browsers.
  Map<String, String> get desktopEnvironment => {
    for (final entry in host.entries)
      if (entry.key.startsWith('XDG_') ||
          entry.key.startsWith('LC_') ||
          const {
            'HOME',
            'PATH',
            'USER',
            'LOGNAME',
            'SHELL',
            'LANG',
            'LANGUAGE',
            'DISPLAY',
            'WAYLAND_DISPLAY',
            'XAUTHORITY',
            'DBUS_SESSION_BUS_ADDRESS',
            'DESKTOP_SESSION',
            'KDE_FULL_SESSION',
            'KDE_SESSION_VERSION',
            'KDE_SESSION_UID',
            'GNOME_DESKTOP_SESSION_ID',
            'MATE_DESKTOP_SESSION_ID',
            'LXQT_SESSION_CONFIG',
            'BROWSER',
            'TMPDIR',
            'GDK_BACKEND',
          }.contains(entry.key))
        entry.key: entry.value,
  };

  Map<String, String> environment(
    Map<String, String> isolated,
    Map<String, String> overrides,
  ) => {
    ...isolated,
    if (!overrides.containsKey('PATH'))
      'PATH': '$directory:${host['PATH'] ?? '/usr/local/bin:/usr/bin:/bin'}',
    if (!overrides.containsKey('BROWSER') && !overrides.containsKey('PATH'))
      'BROWSER': 'xdg-open',
  };

  Future<void> prepare() async {
    await Directory(directory).create(recursive: true);
    final secured = await LinuxCommands.run('/usr/bin/chmod', [
      '700',
      '--',
      directory,
    ]);
    if (secured.exitCode != 0) {
      throw FileSystemException('Cannot secure desktop handlers', directory);
    }
    await LinuxCommands.writePrivateFile(
      p.join(directory, 'environment.json'),
      jsonEncode(desktopEnvironment),
    );
    await LinuxCommands.writePrivateFile(opener, r'''#!/usr/bin/python3
import json,os,shutil,sys
with open(os.path.join(os.path.dirname(os.path.realpath(__file__)), 'environment.json')) as stream:
    environment=json.load(stream)
handler=shutil.which('xdg-open', path=environment.get('PATH', '/usr/local/bin:/usr/bin:/bin'))
if not handler or os.path.realpath(handler) == os.path.realpath(__file__):
    sys.exit('Host xdg-open is unavailable')
# Argument lists preserve OAuth URLs, Unicode and shell metacharacters exactly.
os.execve(handler, [handler]+sys.argv[1:], environment)
''');
    final executable = await LinuxCommands.run('/usr/bin/chmod', [
      '700',
      '--',
      opener,
    ]);
    if (executable.exitCode != 0) {
      throw FileSystemException('Cannot prepare desktop handler', opener);
    }
  }
}
