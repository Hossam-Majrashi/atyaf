class TerminalCommand {
  const TerminalCommand(this.name, this.path, this.inPath);
  final String name, path;
  final bool inPath;
}

class TerminalCommandFailure implements Exception {
  const TerminalCommandFailure(this.code, this.detail);
  final String code, detail;
  @override
  String toString() => '$code: $detail';
}

abstract interface class TerminalCommandService {
  Future<List<TerminalCommand>> terminalCommands(String profileId);
  Future<TerminalCommand> createTerminalCommand(
    String profileId,
    String name, {
    required String argumentsWarning,
  });

  /// Removes only unchanged wrappers owned by this library/profile.
  /// Returns names of modified files left untouched and no longer managed.
  Future<List<String>> removeTerminalCommands(String profileId);
}
