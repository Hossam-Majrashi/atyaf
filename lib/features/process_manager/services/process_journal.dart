import '../../../shared/services/library_repository.dart';

class ProcessJournal {
  ProcessJournal(this.repository);
  final LibraryRepository repository;
  void start({
    required String id,
    required String profileId,
    required int pid,
    required String? identity,
    required String stdoutPath,
    required String stderrPath,
    String? executable,
  }) {
    repository.recordLaunch({
      'id': id,
      'profileId': profileId,
      'pid': pid,
      'identity': identity,
      'start': DateTime.now().toIso8601String(),
      'stop': null,
      'exitCode': null,
      'crashed': false,
      'stdout': stdoutPath,
      'stderr': stderrPath,
      'executable': executable,
    });
  }

  void finish(String id, int code) {
    repository.updateLaunch(id, {
      'stop': DateTime.now().toIso8601String(),
      'exitCode': code,
      'crashed': ![0, -15, -9, 143, 137].contains(code),
    });
  }

  void interrupted(String id) {
    repository.updateLaunch(id, {
      'stop': DateTime.now().toIso8601String(),
      'interrupted': true,
    });
  }
}
