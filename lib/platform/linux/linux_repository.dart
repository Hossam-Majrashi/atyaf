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
  List<Application> get applications =>
      _all('applications').map(Application.fromJson).toList();
  @override
  List<Profile> get profiles => _all('profiles').map(Profile.fromJson).toList();
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
  List<Map<String, dynamic>> history(String profileId) =>
      _all('launches')
          .where((r) => r['profileId'] == profileId)
          .toList()
          .reversed
          .toList();
  @override
  void recordLaunch(Map<String, dynamic> record) => _save('launches', record);
  @override
  List<Map<String, dynamic>> get errors => _all('errors').reversed.toList();
  @override
  void recordError(Map<String, dynamic> record) => _save('errors', record);
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
