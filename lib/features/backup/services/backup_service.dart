abstract interface class BackupService {
  Future<void> export(String destination);
  Future<void> restore(String source);
}
