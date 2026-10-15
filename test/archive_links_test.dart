import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/applications/services/application_service.dart';
import 'package:atyaf/features/updates/services/update_service.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_managed_storage.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LinuxProcesses processes;
  late LinuxArchives archives;
  late LinuxManagedStorage storage;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf archive روابط ');
    runtime = LinuxRuntime(environment: {'HOME': temporary.path});
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    processes = LinuxProcesses(runtime, repository);
    archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
    storage = LinuxManagedStorage(runtime, archives);
  });
  tearDown(() async {
    repository.close();
    await temporary.delete(recursive: true);
  });

  Future<String> fixture(
    List<Map<String, String>> members, {
    String format = 'gz',
    String name = 'fixture',
  }) async {
    final path = '${temporary.path}/$name.tar.$format';
    final result = await Process.run('python3', [
      '-c',
      '''
import io,json,subprocess,sys,tarfile
path,fmt,members=sys.argv[1:]
raw=path+'.raw' if fmt=='zst' else path
with tarfile.open(raw,'w' if fmt=='zst' else 'w:'+fmt) as archive:
    for entry in json.loads(members):
        info=tarfile.TarInfo(entry['name'])
        if 'target' in entry:
            info.type=tarfile.SYMTYPE
            info.linkname=entry['target']
            archive.addfile(info)
        else:
            data=entry.get('data','resource').encode()
            info.size=len(data)
            info.mode=0o6755
            archive.addfile(info,io.BytesIO(data))
if fmt=='zst':
    subprocess.run(['zstd','-q',raw,'-o',path],check=True)
''',
      path,
      format,
      jsonEncode(members),
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return path;
  }

  List<Map<String, String>> package(String version) => [
    // Links precede their targets, as may happen in either tar member order.
    {'name': 'usr/bin/sirb', 'target': '/opt/com.h.sirb/launcher'},
    {'name': 'entry', 'target': '/usr/bin/sirb'},
    {'name': 'assets', 'target': '/opt/com.h.sirb/resources'},
    {'name': 'opt/com.h.sirb/resources/value', 'data': version},
    {
      'name': 'opt/com.h.sirb/launcher',
      'data': '#!/bin/sh\nprintf "$version"\n',
    },
  ];

  for (final format in ['gz', 'xz', 'zst']) {
    test(
      'tar.$format root-relative links survive import, update, folder copy and backup without host dependencies',
      () async {
        final applications = ApplicationService(repository, runtime, storage);
        final updates = UpdateService(repository, runtime, processes, storage);
        final archive = await fixture(package('old'), format: format);
        final source = await storage.stage(archive, archive: true);
        expect(source.executables, containsAll(['usr/bin/sirb', 'entry']));
        expect(repository.applications, isEmpty);
        expect(
          await Link('${source.root}/usr/bin/sirb').target(),
          '../../opt/com.h.sirb/launcher',
        );
        expect(await File('${source.root}/assets/value').readAsString(), 'old');
        final mode = (await File('${source.root}/entry').stat()).mode;
        expect(mode & 0xc00, 0); // Privilege bits are never retained.
        expect(mode & 0x40, isNot(0));
        final app = await applications.addManaged(
          'Sirb',
          source,
          'usr/bin/sirb',
        );
        await storage.discard(source);
        await File(archive).delete();
        final profile = Profile(
          id: 'work',
          applicationId: app.id,
          name: 'Work',
          arguments: ['unchanged'],
          environment: {'KEEP': 'value'},
        );
        repository.saveProfile(profile);
        // Copying a relocated managed tree also remains confined.
        final copy = await storage.stage(app.portableRoot!, archive: false);
        expect(
          await File('${copy.root}/entry').readAsString(),
          contains('old'),
        );
        await storage.discard(copy);
        final next = await storage.stage(
          await fixture(package('new'), format: format, name: 'update'),
          archive: true,
        );
        expect(updates.preferredExecutable(app, next), 'usr/bin/sirb');
        final updated = await updates.update(app, next, 'usr/bin/sirb');
        await storage.discard(next);
        final backup = LinuxBackup(runtime, repository, archives, processes);
        final saved = '${temporary.path}/backup.tar.gz';
        await backup.export(saved);
        await File('${updated.portableRoot}/opt/com.h.sirb/launcher')
            .writeAsString('changed');
        await backup.restore(saved);
        final restored = repository.applications.single;
        expect(repository.profiles.single.toJson(), profile.toJson());
        expect(
          await Link('${restored.portableRoot}/usr/bin/sirb').target(),
          '../../opt/com.h.sirb/launcher',
        );
        expect(
          await File(restored.executable).resolveSymbolicLinks(),
          '${restored.portableRoot}/opt/com.h.sirb/launcher',
        );
        // Only the controlled fixture is executed; importing never launches it.
        final result = await Process.run(restored.executable, []);
        expect(result.exitCode, 0);
        expect(result.stdout, 'new');
        expect(
          await Directory('${runtime.root}/staging').list().toList(),
          isEmpty,
        );
      },
    );
  }

  final attacks = <String, List<Map<String, String>>>{
    'host absolute target': [
      {'name': 'entry', 'target': '/etc/passwd'},
    ],
    'relative escape': [
      {'name': 'entry', 'target': '../outside'},
    ],
    'absolute traversal': [
      {'name': 'entry', 'target': '/opt/../../etc/passwd'},
    ],
    'absolute symlink parent write': [
      {'name': 'entry', 'target': '/opt'},
      {'name': 'entry/child', 'data': 'bad'},
      {'name': 'opt/keep', 'data': 'safe'},
    ],
    'escaping chain': [
      {'name': 'entry', 'target': '/opt/alias'},
      {'name': 'opt/alias', 'target': '../../outside'},
    ],
    'chain escape after parent resolution': [
      {'name': 'entry', 'target': 'alias/../outside'},
      {'name': 'alias', 'target': '.'},
    ],
    'absolute link cycle': [
      {'name': 'entry', 'target': '/other'},
      {'name': 'other', 'target': '/entry'},
    ],
    'dangling relative link': [
      {'name': 'entry', 'target': 'missing'},
    ],
    'empty target': [
      {'name': 'entry', 'target': ''},
    ],
    'backslash target': [
      {'name': 'entry', 'target': r'/opt\file'},
    ],
    'control character target': [
      {'name': 'entry', 'target': '/opt/line\nfile'},
    ],
  };
  for (final attack in attacks.entries) {
    test('Archive rejects ${attack.key} and removes failed staging', () async {
      // A valid binary cannot cause an unsafe package to be partly accepted.
      final archive = await fixture([
        ...attack.value,
        {'name': 'safe', 'data': '#!/bin/sh\nexit 0\n'},
      ]);
      await expectLater(
        storage.stage(archive, archive: true),
        throwsStateError,
      );
      expect(
        await Directory('${runtime.root}/staging').list().toList(),
        isEmpty,
      );
      expect(repository.applications, isEmpty);
      expect(repository.profiles, isEmpty);
    });
  }
}
