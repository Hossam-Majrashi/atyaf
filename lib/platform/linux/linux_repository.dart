import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';

import '../../shared/models/library_models.dart';
import '../../shared/services/library_repository.dart';

class LinuxRepository implements LibraryRepository {
  LinuxRepository(this.path) : db = openDatabase(path) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA busy_timeout=5000');
    for (final table in ['applications', 'profiles', 'launches', 'errors']) {
      db.execute(
        'CREATE TABLE IF NOT EXISTS $table (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
    }
    db.execute(
      "CREATE INDEX IF NOT EXISTS launches_profile ON launches(json_extract(payload, '\$.profileId'))",
    );
  }
  static Database openDatabase(String path) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
    return sqlite3.open(path);
  }

  final Database db;
  final String path;
  bool locked = false;
  (int, int)? _libraryVersion;
  List<Application>? _applications;
  List<Profile>? _profiles;

  void _checkLibraryVersion() {
    // data_version observes other connections; total_changes observes this one,
    // including direct database writes during restore. Never retain a snapshot
    // across a transaction, which may subsequently roll back.
    final version = (
      db.select('PRAGMA data_version').single.values.single as int,
      db.select('SELECT total_changes()').single.values.single as int,
    );
    if (!db.autocommit || version != _libraryVersion) {
      _applications = null;
      _profiles = null;
      _libraryVersion = db.autocommit ? version : null;
    }
  }

  @override
  Future<T> withExclusiveLock<T>(Future<T> Function() operation) async {
    if (locked) {
      throw StateError('Library is busy');
    }
    locked = true;
    RandomAccessFile? handle;
    bool acquired = false;
    try {
      handle = await File('$path.lock').open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      acquired = true;
      return await operation();
    } finally {
      if (acquired) {
        await handle!.unlock();
      }
      await handle?.close();
      locked = false;
    }
  }

  List<Map<String, dynamic>> _all(String table) => db
      .select('SELECT payload FROM $table ORDER BY rowid')
      .map((r) => decodeRecord(r['payload'] as String))
      .toList();
  void _save(String table, Map<String, dynamic> value) => db.execute(
    'INSERT INTO $table(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
    [value['id'], jsonEncode(value)],
  );
  @override
  List<Application> get applications {
    _checkLibraryVersion();
    return _applications ??= List.unmodifiable(
      _all('applications').map(Application.fromJson),
    );
  }

  @override
  List<Profile> get profiles {
    _checkLibraryVersion();
    return _profiles ??= List.unmodifiable(
      _all('profiles').map((record) {
        final profile = Profile.fromJson(record);
        return Profile(
          id: profile.id,
          applicationId: profile.applicationId,
          name: profile.name,
          arguments: List.unmodifiable(profile.arguments),
          environment: Map.unmodifiable(profile.environment),
          workingDirectory: profile.workingDirectory,
          paths: Map.unmodifiable(profile.paths),
          trustedFingerprint: profile.trustedFingerprint,
        );
      }),
    );
  }

  @override
  void saveApplication(Application application) =>
      _save('applications', application.toJson());
  @override
  void saveProfile(Profile profile) => _save('profiles', profile.toJson());
  @override
  void removeApplication(String id) =>
      db.execute('DELETE FROM applications WHERE id=?', [id]);
  @override
  void removeProfile(String id) {
    db.execute('DELETE FROM profiles WHERE id=?', [id]);
    for (final record in history(id)) {
      db.execute('DELETE FROM launches WHERE id=?', [record['id']]);
    }
  }

  @override
  List<Map<String, dynamic>> history(String profileId) => db
      .select(
        "SELECT payload FROM launches WHERE json_extract(payload, '\$.profileId')=? ORDER BY rowid DESC",
        [profileId],
      )
      .map((row) => decodeRecord(row['payload'] as String))
      .toList();
  @override
  void recordLaunch(Map<String, dynamic> record) => _save('launches', record);
  @override
  List<Map<String, dynamic>> get errors => _all('errors').reversed.toList();
  @override
  void recordError(Map<String, dynamic> record) => _save('errors', record);
  @override
  void clearDiagnostics({
    required Iterable<String> errorIds,
    required Iterable<Map<String, dynamic>> failedLaunches,
  }) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final id in errorIds.toSet()) {
        db.execute('DELETE FROM errors WHERE id=?', [id]);
      }
      for (final record in failedLaunches) {
        if (record['stop'] == null ||
            record['diagnosticsDismissed'] == true ||
            (record['crashed'] != true && record['interrupted'] != true)) {
          continue;
        }
        // Compare the captured payload: an exit/failure arriving while the
        // confirmation was open is a new diagnostic and must stay visible.
        db.execute('UPDATE launches SET payload=? WHERE id=? AND payload=?', [
          jsonEncode({...record, 'diagnosticsDismissed': true}),
          record['id'],
          jsonEncode(record),
        ]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  void updateLaunch(String id, Map<String, dynamic> values) {
    final rows = db.select('SELECT payload FROM launches WHERE id=?', [id]);
    if (rows.isNotEmpty) {
      _save('launches', {
        ...decodeRecord(rows.first['payload'] as String),
        ...values,
      });
    }
  }

  @override
  void snapshot(String destination) =>
      db.execute('VACUUM INTO ?', [destination]);
  @override
  void close() => db.dispose();
}
