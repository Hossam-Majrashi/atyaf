import 'dart:convert';
import 'dart:io';

import '../../features/desktop_entries/services/terminal_command_service.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_commands.dart';
import 'linux_runtime.dart';

class LinuxTerminalCommands implements TerminalCommandService {
  LinuxTerminalCommands(this.runtime, this.executable, {String? helper})
    : helper =
          helper ?? File('assets/linux/terminal_commands.py').absolute.path;
  final RuntimeService runtime;
  final String executable, helper;

  Future<dynamic> operation(
    String operation,
    String profileId, {
    String? name,
    String? argumentsWarning,
  }) async {
    runtime.profileRoot(profileId);
    final host = runtime is LinuxRuntime
        ? (runtime as LinuxRuntime).host
        : Platform.environment;
    final result = await LinuxCommands.run('/usr/bin/python3', [
      helper,
      jsonEncode({
        'root': runtime.root,
        'home': host['HOME'],
        'dataHome': runtime.dataHome,
        'path': host['PATH'] ?? '/usr/local/bin:/usr/bin:/bin',
        'operation': operation,
        'profile': profileId,
        'name': name,
        'argumentsWarning': argumentsWarning,
        'launcher': LinuxCommands.flatpak
            ? ['/usr/bin/flatpak', 'run', 'com.h.atyaf']
            : [executable],
      }),
    ]);
    if (result.exitCode != 0) {
      throw TerminalCommandFailure('unsafe', result.stderr.toString());
    }
    final response = jsonDecode(result.stdout.toString()) as Map;
    if (response['error'] != null) {
      throw TerminalCommandFailure(
        response['error'] as String,
        response['detail'] as String,
      );
    }
    return response['ok'];
  }

  TerminalCommand command(Map value) => TerminalCommand(
    value['name'] as String,
    value['path'] as String,
    value['inPath'] as bool,
  );

  @override
  Future<List<TerminalCommand>> terminalCommands(String profileId) async => [
    for (final value in await operation('list', profileId) as List)
      command(value as Map),
  ];

  @override
  Future<TerminalCommand> createTerminalCommand(
    String profileId,
    String name, {
    required String argumentsWarning,
  }) async => command(
    await operation(
      'create',
      profileId,
      name: name,
      argumentsWarning: argumentsWarning,
    ) as Map,
  );

  @override
  Future<List<String>> removeTerminalCommands(String profileId) async =>
      List<String>.from(await operation('remove', profileId) as List);
}
