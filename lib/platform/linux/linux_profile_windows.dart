import 'dart:convert';
import 'dart:io';

import 'linux_commands.dart';
import 'linux_runtime.dart';

/// Best-effort KDE integration, separate from approval and process ownership.
class LinuxProfileWindows {
  LinuxProfileWindows(this.runtime, this.helper);
  final LinuxRuntime runtime;
  final String helper;

  Future<void> update(
    String profileId,
    int pid,
    String identity, {
    required bool activate,
  }) async {
    final desktop =
        '${runtime.dataHome}/applications/'
        'com.h.atyaf.profile-$profileId.desktop';
    if (!await File(desktop).exists() ||
        !(runtime.host['XDG_CURRENT_DESKTOP'] ?? '')
            .split(':')
            .any((value) => value.toUpperCase() == 'KDE')) {
      return;
    }
    try {
      // The helper validates the boot/start identity again on the host. Its
      // calls have deadlines and its temporary compositor script is unloaded.
      await LinuxCommands.run('/usr/bin/python3', [
        helper,
        jsonEncode({
          'pid': pid,
          'identity': identity,
          'desktop': desktop,
          'activate': activate,
        }),
      ]);
    } on ProcessException {
      // Optional cosmetic/focus support must never prevent a profile launch.
    } on FileSystemException {
      // The shortcut/helper may have been removed since the initial check.
    }
  }
}
