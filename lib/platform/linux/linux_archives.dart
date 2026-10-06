import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../features/archives/services/archive_service.dart';
import '../../shared/services/runtime_service.dart';
import 'linux_commands.dart';

class LinuxArchives implements ArchiveService {
  LinuxArchives(this.runtime, this.helper);
  final RuntimeService runtime;
  final String helper;
  Future<void> invoke(List<String> arguments) async {
    final result = await LinuxCommands.run('/usr/bin/python3', [
      helper,
      ...arguments,
    ]);
    if (result.exitCode != 0) {
      throw StateError(result.stderr.toString().trim());
    }
  }

  @override
  Future<void> extractTo(String source, String destination) async {
    if (!['.tar.gz', '.tar.xz', '.tar.zst'].any(source.endsWith)) {
      throw ArgumentError('Unsupported archive format');
    }
    await invoke([
      'extract',
      LinuxCommands.hostPath(File(source).absolute.path),
      destination,
    ]);
  }

  @override
  Future<String> extractPortable(String source) async {
    final target = '${runtime.root}/portable/${const Uuid().v4()}';
    await Directory('${runtime.root}/portable').create(recursive: true);
    await extractTo(source, target);
    return target;
  }
}
