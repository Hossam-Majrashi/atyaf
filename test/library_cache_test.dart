import 'dart:convert';
import 'dart:io';

import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LinuxRepository repository;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf-library-cache-');
    repository = LinuxRepository('${temporary.path}/library.sqlite');
    repository.saveApplication(
      Application(
        id: 'app',
        name: 'Application',
        executable: '/usr/bin/true',
        iconPng: base64Encode(
          await File('assets/icon/icon-64.png').readAsBytes(),
        ),
      ),
    );
    repository.saveProfile(
      const Profile(id: 'p', applicationId: 'app', name: 'Profile'),
    );
  });
  tearDown(() async {
    repository.close();
    await temporary.delete(recursive: true);
  });

  test('Unchanged library reuses validated icons and immutable snapshots', () {
    final applications = repository.applications;
    final profiles = repository.profiles;
    for (var i = 0; i < 100; i++) {
      expect(repository.applications, same(applications));
      expect(repository.profiles, same(profiles));
    }
    expect(() => applications.clear(), throwsUnsupportedError);
    expect(
      () => profiles.single.arguments.add('changed'),
      throwsUnsupportedError,
    );
    expect(
      () => profiles.single.environment['X'] = 'changed',
      throwsUnsupportedError,
    );
    expect(() => profiles.single.paths.clear(), throwsUnsupportedError);
  });

  test('Local saves, deletion and raw restore writes invalidate snapshots', () {
    final before = repository.applications;
    repository.saveApplication(
      Application.fromJson({...before.single.toJson(), 'name': 'Renamed'}),
    );
    expect(repository.applications.single.name, 'Renamed');
    expect(repository.applications, isNot(same(before)));
    repository.db.execute('DELETE FROM applications');
    expect(repository.applications, isEmpty);
    repository.removeProfile('p');
    expect(repository.profiles, isEmpty);
  });

  test('Other connections expose committed changes without reopening', () {
    final other = LinuxRepository(repository.path);
    try {
      final before = repository.applications;
      final profile = repository.profiles.single;
      other.saveApplication(
        Application.fromJson({...before.single.toJson(), 'name': 'External'}),
      );
      other.saveProfile(
        Profile.fromJson({...profile.toJson(), 'name': 'External profile'}),
      );
      expect(repository.applications.single.name, 'External');
      expect(repository.profiles.single.name, 'External profile');
      expect(repository.applications.single.iconPng, before.single.iconPng);
      other.removeApplication('app');
      expect(repository.applications, isEmpty);
    } finally {
      other.close();
    }
  });

  test(
    'Rolled-back and committed transactions never retain tentative records',
    () {
      final original = repository.applications.single;
      repository.db.execute('BEGIN IMMEDIATE');
      repository.saveApplication(
        Application.fromJson({...original.toJson(), 'name': 'Tentative'}),
      );
      expect(repository.applications.single.name, 'Tentative');
      repository.db.execute('ROLLBACK');
      expect(repository.applications.single.name, original.name);
      repository.db.execute('BEGIN IMMEDIATE');
      repository.db.execute('DELETE FROM applications');
      expect(repository.applications, isEmpty);
      repository.db.execute('COMMIT');
      expect(repository.applications, isEmpty);
    },
  );

  test('Indexed history is isolated, newest first and parameter bound', () {
    const profileId = "account' OR 1=1 -- العربية";
    for (var i = 0; i < 1000; i++) {
      repository.recordLaunch({
        'id': 'launch-$i',
        'profileId': i.isEven ? profileId : 'other',
        'start': 'unchanged',
      });
    }
    final history = repository.history(profileId);
    expect(history.length, 500);
    expect(history.first['id'], 'launch-998');
    expect(history.last['id'], 'launch-0');
    expect(history.every((record) => record['profileId'] == profileId), isTrue);
    final plan = repository.db.select(
      "EXPLAIN QUERY PLAN SELECT payload FROM launches WHERE json_extract(payload, '\$.profileId')=? ORDER BY rowid DESC",
      [profileId],
    );
    expect(
      plan.map((row) => row['detail']).join(),
      contains('launches_profile'),
    );
    repository.updateLaunch('launch-998', {'stop': 'finished', 'exitCode': 0});
    expect(repository.history(profileId).first['exitCode'], 0);
    repository.removeProfile(profileId);
    expect(repository.history(profileId), isEmpty);
    expect(repository.history('other').length, 500);
  });

  test('Invalid externally replaced icons are still validated', () {
    final record = repository.applications.single.toJson();
    final other = LinuxRepository(repository.path);
    try {
      other.db.execute('UPDATE applications SET payload=? WHERE id=?', [
        jsonEncode({...record, 'iconPng': 'invalid'}),
        'app',
      ]);
      expect(() => repository.applications, throwsFormatException);
      other.saveApplication(Application.fromJson(record));
      expect(repository.applications.single.iconPng, record['iconPng']);
    } finally {
      other.close();
    }
  });
}
