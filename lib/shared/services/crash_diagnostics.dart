abstract interface class CrashDiagnostics {
  Future<String> info(Map<String, dynamic> launch);
}
