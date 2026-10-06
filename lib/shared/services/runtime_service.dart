import '../models/library_models.dart';

abstract interface class RuntimeService {
  String get root;
  String get dataHome;
  String profileRoot(String id);
  Map<String, String> resolvedPaths(Profile profile);
  Map<String, String> environmentFor(Profile profile);
  List<String> argumentsFor(Profile profile);
  Future<ExecutableReview> inspect(String path);
  Future<List<String>> discover(String directory);
  Future<void> prepare(Profile profile);
  Future<void> cleanupTemporary(String profileId);
  Future<void> deleteManaged(String path);
}
