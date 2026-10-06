import 'dart:async';
import 'dart:io';

import '../../shared/services/crash_diagnostics.dart';
import 'linux_commands.dart';

class LinuxCrashDiagnostics implements CrashDiagnostics {
  LinuxCrashDiagnostics({
    Future<ProcessResult> Function(String, List<String>)? run,
  }) : run = run ?? LinuxCommands.run;
  final Future<ProcessResult> Function(String, List<String>) run;

  @override
  Future<String> info(Map<String, dynamic> launch) async {
    final pid = launch['pid'];
    final identity = launch['identity'] as String? ?? '';
    final boot = identity.split(':').first.replaceAll('-', '');
    final executable = launch['executable'];
    final start = DateTime.tryParse(launch['start'] as String? ?? '');
    final stop = DateTime.tryParse(launch['stop'] as String? ?? '');
    if (launch['crashed'] != true ||
        pid is! int ||
        pid <= 0 ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(boot) ||
        start == null ||
        stop == null ||
        stop.isBefore(start) ||
        executable is! String ||
        !executable.startsWith('/') ||
        executable.contains('\x00')) {
      return '';
    }
    try {
      final available = await run('/usr/bin/test', [
        '-x',
        '/usr/bin/coredumpctl',
      ]);
      if (available.exitCode != 0) return '';
      final uid = await run('/usr/bin/id', ['-u']);
      final owner = uid.stdout.toString().trim();
      if (uid.exitCode != 0 || !RegExp(r'^\d+$').hasMatch(owner)) return '';
      final result = await run('/usr/bin/coredumpctl', [
        'info',
        '--no-pager',
        '--since=@${start.millisecondsSinceEpoch ~/ 1000}',
        '--until=@${stop.millisecondsSinceEpoch ~/ 1000 + 1}',
        'COREDUMP_PID=$pid',
        'COREDUMP_UID=$owner',
        '_BOOT_ID=$boot',
        'COREDUMP_EXE=$executable',
      ]).timeout(const Duration(seconds: 10));
      return '${result.stdout}${result.stderr}'.trim();
    } on ProcessException catch (error) {
      return error.toString();
    } on TimeoutException catch (error) {
      return error.toString();
    }
  }
}
