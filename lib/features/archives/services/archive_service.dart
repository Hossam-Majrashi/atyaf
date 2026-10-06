abstract interface class ArchiveService {
  Future<String> extractPortable(String source);
  Future<void> extractTo(String source, String destination);
}
