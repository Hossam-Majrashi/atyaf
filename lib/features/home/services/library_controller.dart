import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/crash_diagnostics.dart';

import '../../../shared/models/library_models.dart';
import '../../../shared/services/library_repository.dart';
import '../../../shared/services/runtime_service.dart';
import '../../applications/services/application_service.dart';
import '../../profiles/services/profile_service.dart';
import '../../archives/services/archive_service.dart';
import '../../backup/services/backup_service.dart';
import '../../desktop_entries/services/desktop_entry_service.dart';
import '../../launcher/services/launcher_service.dart';
import '../../logs/services/log_service.dart';
import '../../../shared/services/managed_storage_service.dart';
import '../../updates/services/update_service.dart';
import '../../../shared/services/process_service.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.repository,
    required this.runtime,
    required this.archives,
    required this.backup,
    required this.entries,
    required this.processes,
    required this.storage,
    CrashDiagnostics? diagnostics,
  }) {
    applicationsService = ApplicationService(repository, runtime, storage);
    updates = UpdateService(repository, runtime, processes, storage);
    profilesService = ProfileService(repository, runtime);
    launcher = LauncherService(repository, runtime, processes);
    logs = LogService(runtime, diagnostics: diagnostics);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      processes.reconcile();
      notifyListeners();
    });
  }
  final LibraryRepository repository;
  final RuntimeService runtime;
  final ArchiveService archives;
  final BackupService backup;
  final DesktopEntryService entries;
  final ProcessService processes;
  final ManagedStorageService storage;
  late final UpdateService updates;
  late final ApplicationService applicationsService;
  late final ProfileService profilesService;
  late final LauncherService launcher;
  late final LogService logs;
  late final Timer timer;
  String? selectedId;
  List<Application> get applications => repository.applications;
  Application? get selected {
    final items = applications;
    return items.where((a) => a.id == selectedId).firstOrNull ??
        items.firstOrNull;
  }

  List<Profile> get profiles => repository.profiles
      .where((v) => v.applicationId == selected?.id)
      .toList();
  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void refresh() => notifyListeners();
  void reportError(Object error, StackTrace stack) {
    try {
      repository.recordError({
        'id': const Uuid().v4(),
        'time': DateTime.now().toIso8601String(),
        'detail': error.toString(),
        'stack': stack.toString(),
      });
    } catch (failure) {
      debugPrint('$error\n$stack\nError journal failure: $failure');
    }
  }

  Future<void> deleteProfile(Profile profile) =>
      repository.withExclusiveLock(() => _deleteProfile(profile));
  Future<void> _deleteProfile(Profile profile) async {
    if (processes.isRunning(profile.id)) {
      throw StateError('Stop profile before deletion');
    }
    await entries.remove(profile.id);
    await runtime.cleanupTemporary(profile.id);
    await runtime.deleteManaged(runtime.profileRoot(profile.id));
    repository.removeProfile(profile.id);
    notifyListeners();
  }

  Future<void> deleteApplication(Application application) =>
      repository.withExclusiveLock(() => _deleteApplication(application));
  Future<void> _deleteApplication(Application application) async {
    final items = repository.profiles
        .where((p) => p.applicationId == application.id)
        .toList();
    if (items.any((p) => processes.isRunning(p.id))) {
      throw StateError('Stop all profiles before deletion');
    }
    for (final profile in items) {
      await _deleteProfile(profile);
    }
    if (application.portableRoot != null) {
      await runtime.deleteManaged(application.portableRoot!);
    }
    repository.removeApplication(application.id);
    notifyListeners();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
