import 'dart:io';

final class LinuxCommands {
  LinuxCommands._();
  static Future<void> writePrivateFile(String path, String content) async {
    final file = File(path);
    final staging = await file.parent.createTemp('atyaf-write-');
    try {
      final temporary = File('${staging.path}/content');
      await temporary.writeAsString(content, flush: true);
      final result = await run('/usr/bin/chmod', ['600', '--', temporary.path]);
      if (result.exitCode != 0) {
        throw FileSystemException('Cannot secure private file', path);
      }
      await temporary.rename(path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  static bool get flatpak => Platform.environment.containsKey('FLATPAK_ID');
  static String hostPath(String path) =>
      flatpak && path.startsWith('/run/host/') ? path.substring(9) : path;
  static Future<ProcessResult> run(String executable, List<String> arguments) =>
      flatpak
      ? Process.run('/usr/bin/flatpak-spawn', [
          '--host',
          executable,
          ...arguments,
        ])
      : Process.run(executable, arguments);
}
