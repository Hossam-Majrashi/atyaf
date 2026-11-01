import 'dart:io';

import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Fresh default avoids a partial legacy extraction without deleting it or bypassing approval', () async {
    final temporary = await Directory.systemTemp.createTemp('atyaf-temp-');
    final runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    final repository = LinuxRepository('${runtime.root}/library.sqlite');
    final processes = LinuxProcesses(runtime, repository);
    const id = 'partial';
    final current = runtime.shortTemporary(id);
    final legacy = current.replaceFirst('/var/tmp/', '/tmp/');
    try {
      final prepared = await Process.run('/usr/bin/python3', [
        '-c',
        LinuxRuntime.temporaryHelper,
        p.dirname(legacy),
        p.basename(legacy),
        'prepare',
      ]);
      expect(prepared.exitCode, 0, reason: prepared.stderr.toString());
      final partial = Directory('$legacy/appimage_extracted_fixture');
      await partial.create();
      final marker = File('${partial.path}/AppRun');
      await marker.writeAsString('incomplete extraction, preserve');
      // Model a runtime which reuses an existing extraction directory even
      // when an earlier out-of-space error left its embedded metadata absent.
      final executable = File('${temporary.path}/extractor fixture');
      await executable.writeAsString('''#!/usr/bin/python3
import os,pathlib,sys
root=pathlib.Path(os.environ['TMPDIR'])/'appimage_extracted_fixture'
if not root.exists():
    root.mkdir()
    (root/'fixture.desktop').write_text('[Desktop Entry]')
if not (root/'fixture.desktop').exists():
    print('Error: No .desktop files found',file=sys.stderr)
    sys.exit(1)
print(os.environ['TMPDIR'])
print('complete output النهاية',file=sys.stderr)
''');
      await Process.run('/usr/bin/chmod', ['700', executable.path]);
      final app = Application(
        id: 'app',
        name: 'Fixture',
        executable: executable.path,
      );
      const unapproved = Profile(id: id, applicationId: 'app', name: 'Fixture');
      repository.saveApplication(app);
      repository.saveProfile(unapproved);
      await expectLater(processes.launch(app, unapproved), throwsStateError);
      expect(repository.history(id), isEmpty);
      final review = await runtime.inspect(app.executable);
      final profile = Profile(
        id: id,
        applicationId: 'app',
        name: 'Fixture',
        trustedFingerprint: review.fingerprint,
      );
      repository.saveProfile(profile);
      final control = await Process.run(
        executable.path,
        [],
        environment: {...runtime.environmentFor(profile), 'TMPDIR': legacy},
        includeParentEnvironment: false,
      );
      expect(control.exitCode, 1);
      expect(control.stderr, contains('Error: No .desktop files found'));
      for (var attempt = 0; attempt < 2; attempt++) {
        await processes.launch(app, profile);
        await processes.waitForPendingExits();
        final record = repository.history(id).first;
        expect(record['exitCode'], 0);
        expect(record['crashed'], isFalse);
        expect(
          await File(record['stdout'] as String).readAsString(),
          '$current\n',
        );
        expect(
          await File(record['stderr'] as String).readAsString(),
          'complete output النهاية\n',
        );
      }
      expect(repository.history(id).length, 2);
      expect(await marker.readAsString(), 'incomplete extraction, preserve');
      expect(await File('${partial.path}/fixture.desktop').exists(), isFalse);
      expect(repository.profiles.single.toJson(), profile.toJson());
      expect(repository.errors, isEmpty);
      await runtime.cleanupTemporary(id);
      expect(await Directory(current).exists(), isFalse);
      expect(await marker.exists(), isTrue);
    } finally {
      await processes.waitForPendingExits();
      await runtime.cleanupTemporary(id);
      // Only remove the legacy tree created by this test, through the same
      // no-follow/ownership/private-mode helper as the runtime.
      await Process.run('/usr/bin/python3', [
        '-c',
        LinuxRuntime.temporaryHelper,
        p.dirname(legacy),
        p.basename(legacy),
        'remove',
      ]);
      repository.close();
      await temporary.delete(recursive: true);
    }
  });
}
