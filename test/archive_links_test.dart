import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/applications/services/application_service.dart';
import 'package:atyaf/features/archives/services/archive_service.dart';
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
    String? extension,
  }) async {
    final path = '${temporary.path}/$name.${extension ?? 'tar.$format'}';
    final result = await Process.run('python3', [
      '-c',
      '''
import io,json,subprocess,sys,tarfile
path,fmt,members=sys.argv[1:]
raw=path+'.raw' if fmt=='zst' else path
with tarfile.open(raw,'w' if fmt in ('zst','tar') else 'w:'+fmt) as archive:
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

  for (final (format, suffix) in [
    ('tar', 'TAR'),
    ('gz', 'tGz'),
    ('xz', 'TxZ'),
    ('bz2', 'tar.bz2'),
    ('bz2', 'TbZ2'),
    ('bz2', 'tbz'),
    ('zst', 'tAr.ZsT'),
    ('zst', 'TZST'),
  ]) {
    test(
      'Archive suffix $suffix extracts with its corresponding codec',
      () async {
        final path = await fixture(
          package('test'),
          format: format,
          extension: suffix,
        );
        final staged = await storage.stage(path, archive: true);
        expect(staged.executables, contains('entry'));
        expect(
          await File('${staged.root}/assets/value').readAsString(),
          'test',
        );
        await storage.discard(staged);
      },
    );
  }

  Future<File> zipFixture(String kind, {String value = 'original'}) async {
    final path = '${temporary.path}/portable $value.ZiP';
    final result = await Process.run('python3', [
      '-c',
      r'''
import stat, sys, zipfile
path, kind, value = sys.argv[1:]
with zipfile.ZipFile(path, 'w') as archive:
    def member(name, data, mode=0o100644):
        info = zipfile.ZipInfo(name)
        info.create_system = 3
        info.external_attr = mode << 16
        archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)
    member('bin/', '', stat.S_IFDIR | 0o755)
    member('bin/launcher', '#!/bin/sh\nprintf ' + value, 0o106755)
    member('bin/data', value)
    if kind == 'traversal': member('../outside', 'bad')
    if kind == 'absolute': member('/outside', 'bad')
    if kind == 'alias': member('./bin//data', 'bad')
    if kind == 'link': member('bin/link', 'launcher', stat.S_IFLNK | 0o777)
    if kind == 'pipe': member('pipe', '', stat.S_IFIFO | 0o755)
    if kind == 'backslash': member(r'bin\bad', 'bad')
''',
      path,
      kind,
      value,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return File(path);
  }

  test(
    'ZIP import and replacement preserve executable modes and profile data',
    () async {
      final source = await zipFixture('valid');
      final original = await source.readAsBytes();
      final stage = await storage.stage(source.path, archive: true);
      expect(stage.executables, ['bin/launcher']);
      expect(
        (await File('${stage.root}/bin/launcher').stat()).mode & 0xfff,
        0x1ed,
      );
      final app = await ApplicationService(
        repository,
        runtime,
        storage,
      ).addManaged('Portable program', stage, stage.executables.single);
      await storage.discard(stage);
      final profile = Profile(id: 'work', applicationId: app.id, name: 'Work');
      repository.saveProfile(profile);
      final next = await zipFixture('valid', value: 'replacement');
      final replacement = await storage.stage(next.path, archive: true);
      final updated = await UpdateService(
        repository,
        runtime,
        processes,
        storage,
      ).update(app, replacement, replacement.executables.single);
      await storage.discard(replacement);
      expect(updated.id, app.id);
      expect(
        await File('${updated.portableRoot}/bin/data').readAsString(),
        'replacement',
      );
      expect(repository.profiles.single.toJson(), profile.toJson());
      expect(await source.readAsBytes(), original);
    },
  );

  for (final kind in [
    'traversal',
    'absolute',
    'alias',
    'link',
    'pipe',
    'backslash',
    'corrupt',
  ]) {
    test('ZIP rejects $kind and removes partial staging', () async {
      final path = kind == 'corrupt'
          ? (await File('${temporary.path}/corrupt.zip')
                    .writeAsString('broken'))
                .path
          : (await zipFixture(kind)).path;
      await expectLater(storage.stage(path, archive: true), throwsStateError);
      expect(
        await Directory('${runtime.root}/staging').list().toList(),
        isEmpty,
      );
      expect(repository.applications, isEmpty);
    });
  }

  test(
    'Unsupported archives reject cleanly, and ZIP is not a backup format',
    () async {
      final unsupported = throwsA(isA<UnsupportedArchiveFormat>());
      await expectLater(
        storage.stage('${temporary.path}/test.7z', archive: true),
        unsupported,
      );
      final backup = LinuxBackup(runtime, repository, archives, processes);
      await expectLater(
        backup.restore((await zipFixture('valid')).path),
        unsupported,
      );
      expect(
        await Directory('${runtime.root}/staging').list().toList(),
        isEmpty,
      );
    },
  );

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
