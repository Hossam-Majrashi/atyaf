import 'dart:io';

import 'package:flutter/services.dart';

import '../../features/home/services/library_controller.dart';
import 'linux_runtime.dart';
import 'linux_repository.dart';
import 'linux_archives.dart';
import 'linux_processes.dart';
import 'linux_profile_windows.dart';
import 'linux_desktop_entries.dart';
import 'linux_backup.dart';
import 'linux_commands.dart';
import 'linux_managed_storage.dart';
import 'linux_crash_diagnostics.dart';

final class LinuxIntegration {
  LinuxIntegration._();
  static Future<LibraryController> initialize() async {
    if (!Platform.isLinux) {
      throw UnsupportedError('Atyaf requires Linux');
    }
    Map<String, String>? hostEnvironment;
    if (LinuxCommands.flatpak) {
      final result = await LinuxCommands.run('/usr/bin/env', ['-0']);
      if (result.exitCode != 0) {
        throw StateError('Host environment access failed');
      }
      hostEnvironment = {};
      for (final entry in result.stdout.toString().split('\x00')) {
        final separator = entry.indexOf('=');
        if (separator > 0) {
          hostEnvironment[entry.substring(0, separator)] = entry.substring(
            separator + 1,
          );
        }
      }
    }
    final runtime = LinuxRuntime(environment: hostEnvironment);
    await Directory(runtime.root).create(recursive: true);
    await LinuxCommands.run('/usr/bin/chmod', ['700', '--', runtime.root]);
    final helper = '${runtime.root}/archive_helper.py';
    await LinuxCommands.writePrivateFile(
      helper,
      await rootBundle.loadString('assets/linux/archive_helper.py'),
    );
    await LinuxCommands.writePrivateFile(
      '${runtime.root}/process_helper.py',
      await rootBundle.loadString('assets/linux/process_helper.py'),
    );
    final iconHelper = '${runtime.root}/desktop_icon_helper.py';
    await LinuxCommands.writePrivateFile(
      iconHelper,
      await rootBundle.loadString('assets/linux/desktop_icon_helper.py'),
    );
    final appImageIconHelper = '${runtime.root}/appimage_icons.py';
    await LinuxCommands.writePrivateFile(
      appImageIconHelper,
      await rootBundle.loadString('assets/linux/appimage_icons.py'),
    );
    final terminalHelper = '${runtime.root}/terminal_commands.py';
    await LinuxCommands.writePrivateFile(
      terminalHelper,
      await rootBundle.loadString('assets/linux/terminal_commands.py'),
    );
    final windowHelper = '${runtime.root}/profile_windows.py';
    await LinuxCommands.writePrivateFile(
      windowHelper,
      await rootBundle.loadString('assets/linux/profile_windows.py'),
    );
    final repository = LinuxRepository('${runtime.root}/library.sqlite');
    final processes = LinuxProcesses(
      runtime,
      repository,
      windows: LinuxProfileWindows(runtime, windowHelper),
    );
    processes.reconcile();
    final archives = LinuxArchives(runtime, helper);
    final icon = await rootBundle.load('assets/icon/icon.png');
    final entries = LinuxDesktopEntries(
      runtime,
      icon.buffer.asUint8List(),
      iconHelper: iconHelper,
      terminalHelper: terminalHelper,
    );
    return LibraryController(
      repository: repository,
      runtime: runtime,
      archives: archives,
      storage: LinuxManagedStorage(
        runtime,
        archives,
        appImageIconHelper: appImageIconHelper,
      ),
      backup: LinuxBackup(
        runtime,
        repository,
        archives,
        processes,
        terminalCommands: entries,
      ),
      entries: entries,
      processes: processes,
      diagnostics: LinuxCrashDiagnostics(),
    );
  }
}
