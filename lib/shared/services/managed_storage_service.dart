import '../models/library_models.dart';

class ManagedSource {
  const ManagedSource(
    this.source,
    this.root,
    this.executables, {
    this.isAppImage = false,
    this.isExecutable = false,
    this.defaultIconPng,
    this.appImageIconStatus,
  });
  final bool isAppImage, isExecutable;
  final String? defaultIconPng, appImageIconStatus;
  final String source, root;
  final List<String> executables;
}

abstract interface class ManagedStorageService {
  Future<ManagedSource> stage(String source, {required bool archive});
  Future<ManagedSource> stageAppImage(String source);
  Future<ManagedSource> stageExecutable(String source);
  Future<ExecutableReview> review(ManagedSource source, String relative);
  Future<void> discard(ManagedSource source);
  Future<void> replace(
    ManagedSource source,
    String destination,
    String relative, {
    required void Function() commit,
    Iterable<String> protectedPaths = const [],
  });
}
