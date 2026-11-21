import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atyaf/features/logs/services/log_service.dart';
import 'package:atyaf/platform/linux/linux_archives.dart';
import 'package:atyaf/platform/linux/linux_backup.dart';
import 'package:atyaf/platform/linux/linux_desktop_entries.dart';
import 'package:atyaf/platform/linux/linux_processes.dart';
import 'package:atyaf/platform/linux/linux_repository.dart';
import 'package:atyaf/platform/linux/linux_runtime.dart';
import 'package:atyaf/shared/models/library_models.dart';
import 'package:atyaf/shared/services/process_service.dart';
import 'package:flutter_test/flutter_test.dart';

class DrainingProcesses extends LinuxProcesses {
  DrainingProcesses(super.runtime, super.repository);
  final captured = Completer<void>();
  final release = Completer<void>();
  int streams = 0;
  @override
  Future<void> capture(Stream<List<int>> stream, String path) async {
    await super.capture(stream, path);
    if (++streams == 2) captured.complete();
    await release.future;
  }
}

void main() {
  late Directory temporary;
  late LinuxRuntime runtime;
  late LinuxRepository repository;
  late LinuxProcesses processes;
  late LinuxArchives archives;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('atyaf خدمات space-');
    runtime = LinuxRuntime(
      environment: {
        ...Platform.environment,
        'HOME': temporary.path,
        'XDG_DATA_HOME': '${temporary.path}/data',
        'XDG_CONFIG_HOME': '',
        'XDG_STATE_HOME': 'relative',
        'XDG_CACHE_HOME': 'relative',
      },
    );
    await Directory(runtime.root).create(recursive: true);
    repository = LinuxRepository('${runtime.root}/library.sqlite');
    processes = LinuxProcesses(runtime, repository);
    archives = LinuxArchives(
      runtime,
      File('assets/linux/archive_helper.py').absolute.path,
    );
  });
  tearDown(() async {
    for (final p in repository.profiles) {
      if (processes.isRunning(p.id)) {
        await processes.stop(p.id, force: true);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    repository.close();
    await temporary.delete(recursive: true);
  });
  Future<void> settled(String id) async {
    for (var i = 0; i < 100; i++) {
      if (repository.history(id).firstOrNull?['stop'] != null) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('Process failed to settle');
  }

  test('XDG fallback, independent profiles, HOME unchanged, arguments and environment stay separate', () async {
    const a = Profile(
      id: 'a',
      applicationId: 'app',
      name: 'A',
      arguments: ['--user-data-dir={data}', r'a b;$(touch bad)', 'العربية'],
      environment: {
        'CUSTOM': '{config}/file with spaces',
        'UNCHANGED': r'literal$HOME',
      },
    );
    const b = Profile(id: 'b', applicationId: 'app', name: 'B');
    expect(runtime.configHome, '${temporary.path}/.config');
    expect(runtime.stateHome, '${temporary.path}/.local/state');
    expect(runtime.environmentFor(a)['HOME'], temporary.path);
    expect(
      runtime.environmentFor(a)['XDG_DATA_HOME'],
      isNot(runtime.environmentFor(b)['XDG_DATA_HOME']),
    );
    expect(runtime.argumentsFor(a)[1], r'a b;$(touch bad)');
    expect(runtime.argumentsFor(a)[2], 'العربية');
    expect(runtime.environmentFor(a)['UNCHANGED'], r'literal$HOME');
    expect(runtime.host.containsKey('CUSTOM'), isFalse);
    await runtime.prepare(a);
    expect(
      await Directory(runtime.resolvedPaths(a)['cache']!).exists(),
      isTrue,
    );
    expect(
      () => runtime.environmentFor(
        const Profile(
          id: 'x',
          applicationId: 'app',
          name: 'X',
          environment: {'A=B': 'x'},
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'NVIDIA PRIME environment is delivered only to the opted-in child',
    () async {
      final isolated = LinuxRuntime(environment: {'HOME': temporary.path});
      final launches = LinuxProcesses(isolated, repository);
      final file = File('${temporary.path}/graphics-probe');
      await file.writeAsString(r'''#!/bin/sh
printf '%s:%s\n' "${__NV_PRIME_RENDER_OFFLOAD:-unset}" "${__GLX_VENDOR_LIBRARY_NAME:-unset}"
''');
      expect(
        (await Process.run('chmod', ['700', '--', file.path])).exitCode,
        0,
      );
      final application = Application(
        id: 'app',
        name: 'Probe',
        executable: file.path,
      );
      repository.saveApplication(application);
      final review = await isolated.inspect(file.path);
      for (final id in ['prime', 'ordinary']) {
        final profile = Profile(
          id: id,
          applicationId: application.id,
          name: id,
          trustedFingerprint: review.fingerprint,
          environment: id == 'prime'
              ? {
                  '__NV_PRIME_RENDER_OFFLOAD': '1',
                  '__GLX_VENDOR_LIBRARY_NAME': 'nvidia',
                }
              : {},
        );
        repository.saveProfile(profile);
        addTearDown(() => isolated.cleanupTemporary(id));
        await launches.launch(application, profile);
        await launches.drainLocalSupervision();
        final record = repository.history(id).single;
        expect(record['exitCode'], 0);
        expect(
          await File(record['stdout'] as String).readAsString(),
          id == 'prime' ? '1:nvidia\n' : 'unset:unset\n',
        );
      }
      expect(isolated.host.keys, isNot(contains('__NV_PRIME_RENDER_OFFLOAD')));
      expect(isolated.host.keys, isNot(contains('__GLX_VENDOR_LIBRARY_NAME')));
    },
  );

  test('Host-data substitution is opt-in, relocatable and independent of profile paths', () {
    const ordinary = Profile(
      id: 'ordinary',
      applicationId: 'app',
      name: 'Ordinary',
    );
    const connected = Profile(
      id: 'connected',
      applicationId: 'app',
      name: 'Connected',
      paths: {'data': '/custom/isolated'},
      environment: {'MDM_DATA_DIR': '{hostData}/misterdownloadmanager'},
      arguments: ['{hostData}', '{data}'],
    );
    expect(
      runtime.environmentFor(ordinary).containsKey('MDM_DATA_DIR'),
      runtime.host.containsKey('MDM_DATA_DIR'),
    );
    expect(
      runtime.environmentFor(connected)['MDM_DATA_DIR'],
      '${runtime.dataHome}/misterdownloadmanager',
    );
    expect(
      runtime.environmentFor(connected)['XDG_DATA_HOME'],
      '/custom/isolated',
    );
    expect(runtime.argumentsFor(connected), [
      runtime.dataHome,
      '/custom/isolated',
    ]);
    final relocated = LinuxRuntime(
      environment: {
        'HOME': '${temporary.path}/new home',
        'XDG_DATA_HOME': 'relative',
      },
    );
    expect(
      relocated.environmentFor(connected)['MDM_DATA_DIR'],
      '${temporary.path}/new home/.local/share/misterdownloadmanager',
    );
    expect(runtime.host.containsKey('CUSTOM'), isFalse);
  });

  test('Browser host and supervised MDM-style instance share IPC without a second launch or data migration', () async {
    final oldData = File(
      '${runtime.profileRoot('mdm')}/data/misterdownloadmanager/keep',
    );
    await oldData.parent.create(recursive: true);
    await oldData.writeAsString('isolated data remains');
    const app = Application(
      id: 'app',
      name: 'IPC fixture',
      executable: '/usr/bin/python3',
    );
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'mdm',
      applicationId: app.id,
      name: 'Browser connected',
      trustedFingerprint: review.fingerprint,
      environment: const {'MDM_DATA_DIR': '{hostData}/misterdownloadmanager'},
      arguments: const [
        '-c',
        r'''
import json,os,socket,pathlib,sys
folder=pathlib.Path(os.environ['MDM_DATA_DIR'])
folder.mkdir(parents=True,exist_ok=True)
server=socket.socket(); server.bind(('127.0.0.1',0)); server.listen(1); server.settimeout(10)
(folder/'ipc.json').write_text(json.dumps({'port':server.getsockname()[1],'token':'fixture-only'}))
with server.accept()[0] as client:
    data=json.loads(client.makefile().readline())
    assert data['token']=='fixture-only'
    print(json.dumps([data['url'],os.environ['XDG_DATA_HOME'],os.environ['MDM_DATA_DIR']]),flush=True)
    print('complete stderr',file=sys.stderr)
    client.sendall(b'ok\n')
server.close()
''',
      ],
    );
    repository.saveApplication(app);
    repository.saveProfile(profile);
    await processes.launch(app, profile);
    final endpoint = File('${runtime.dataHome}/misterdownloadmanager/ipc.json');
    for (var i = 0; i < 100 && !await endpoint.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await endpoint.exists(), isTrue);
    const url =
        'https://example.invalid/file%20with%20spaces?value=العربية&x=1';
    // A host browser does not inherit this profile's isolated XDG environment.
    // This fixture follows upstream mdm-ipc::data_dir, using a disposable IPC
    // endpoint only; it never launches a browser or downloads anything.
    final browser = await Process.run(
      '/usr/bin/python3',
      [
        '-c',
        r'''
import json,os,pathlib,socket,sys
folder=pathlib.Path(os.environ.get('MDM_DATA_DIR',str(pathlib.Path(os.environ['XDG_DATA_HOME'])/'misterdownloadmanager')))
ep=json.loads((folder/'ipc.json').read_text())
with socket.create_connection(('127.0.0.1',ep['port']),timeout=5) as client:
    client.sendall((json.dumps({'token':ep['token'],'url':sys.argv[1]})+'\n').encode())
    print(client.makefile().readline().strip())
''',
        url,
      ],
      environment: {...runtime.host}..remove('MDM_DATA_DIR'),
      includeParentEnvironment: false,
    );
    expect(browser.exitCode, 0, reason: browser.stderr.toString());
    expect(browser.stdout.toString().trim(), 'ok');
    await settled(profile.id);
    final history = repository.history(profile.id);
    expect(history, hasLength(1));
    expect(history.single['exitCode'], 0);
    expect(
      jsonDecode(
        (await File(history.single['stdout'] as String).readAsString()).trim(),
      ),
      [
        url,
        runtime.resolvedPaths(profile)['data'],
        '${runtime.dataHome}/misterdownloadmanager',
      ],
    );
    expect(
      await File(history.single['stderr'] as String).readAsString(),
      'complete stderr\n',
    );
    expect(await oldData.readAsString(), 'isolated data remains');
    await runtime.deleteManaged(runtime.profileRoot(profile.id));
    expect(
      await endpoint.exists(),
      isTrue,
    ); // Host data is never profile-owned.
  });

  test('X11 capability and explicit GTK backend are profile-local without changing Wayland session, paths or other settings', () {
    final host = {
      ...runtime.host,
      'DISPLAY': ':99',
      'WAYLAND_DISPLAY': 'wayland-0',
      'GDK_BACKEND': 'wayland',
    };
    final desktop = LinuxRuntime(environment: host);
    expect(desktop.hasX11Display, isTrue);
    expect(
      LinuxRuntime(environment: {...host, 'DISPLAY': ''}).hasX11Display,
      isFalse,
    );
    const profile = Profile(
      id: 'gtk',
      applicationId: 'app',
      name: 'GTK',
      arguments: ['unchanged'],
      environment: {'GDK_BACKEND': 'x11', 'KEEP': 'unchanged'},
    );
    final values = desktop.environmentFor(profile);
    expect(values['GDK_BACKEND'], 'x11');
    expect(values['DISPLAY'], ':99');
    expect(values['WAYLAND_DISPLAY'], 'wayland-0');
    expect(values['KEEP'], 'unchanged');
    expect(values['XDG_CONFIG_HOME'], desktop.resolvedPaths(profile)['config']);
    expect(desktop.argumentsFor(profile), ['unchanged']);
    expect(desktop.host, host);
    expect(desktop.host['GDK_BACKEND'], 'wayland');
  });

  test('Managed deletion rejects external paths and escaping parent symlinks; leaves symlink target intact', () async {
    final outside = Directory('${temporary.path}/outside');
    await outside.create();
    await File('${outside.path}/keep').writeAsString('safe');
    await expectLater(runtime.deleteManaged(outside.path), throwsArgumentError);
    await expectLater(runtime.deleteManaged(runtime.root), throwsArgumentError);
    await Link('${runtime.root}/link').create(outside.path);
    await expectLater(
      runtime.deleteManaged('${runtime.root}/link/keep'),
      throwsArgumentError,
    );
    await runtime.deleteManaged('${runtime.root}/link');
    expect(await File('${outside.path}/keep').exists(), isTrue);
    expect(() => runtime.profileRoot('../outside'), throwsArgumentError);
  });

  test(
    'Executable validation, canonical symlinks, spaces and Unicode',
    () async {
      final file = File('${temporary.path}/برنامج ; executable ');
      await file.writeAsString('#!/bin/sh\nprintf ok');
      await expectLater(
        runtime.inspect(file.path),
        throwsA(isA<FileSystemException>()),
      );
      await Process.run('chmod', ['700', '--', file.path]);
      final link = Link('${temporary.path}/shortcut');
      await link.create(file.path);
      final review = await runtime.inspect(link.path);
      expect(review.path, file.path);
      expect(review.size, greaterThan(0));
      expect(review.owner, isNotEmpty);
      await Process.run('chmod', ['4700', '--', file.path]);
      await expectLater(
        runtime.inspect(file.path),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('Process arguments, environment, cwd, logs, PID and exit are recorded without shell injection', () async {
    final app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    repository.saveApplication(app);
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'safe',
      applicationId: app.id,
      name: 'Safe',
      trustedFingerprint: review.fingerprint,
      arguments: [
        '-c',
        'import os,sys,json; print(json.dumps([sys.argv[1:],os.environ["CUSTOM"],os.getcwd()],ensure_ascii=False)); print("stderr",file=sys.stderr)',
        'العربية with spaces',
        '; touch ${temporary.path}/injected',
      ],
      environment: {'CUSTOM': r'literal;$(echo bad)'},
      workingDirectory: temporary.path,
    );
    repository.saveProfile(profile);
    await processes.launch(app, profile);
    await settled(profile.id);
    final record = repository.history(profile.id).first;
    final output = jsonDecode(
      (await File(record['stdout'] as String).readAsString()).trim(),
    ) as List;
    expect(output[0], profile.arguments.sublist(2));
    expect(output[1], r'literal;$(echo bad)');
    expect(output[2], temporary.path);
    expect(await File('${temporary.path}/injected').exists(), isFalse);
    expect(
      await File(record['stderr'] as String).readAsString(),
      contains('stderr'),
    );
    expect(record['pid'], isA<int>());
    expect(record['exitCode'], 0);
    expect(record['crashed'], isFalse);
    expect(processes.isRunning(profile.id), isFalse);
  });

  test('Graceful stop, duplicate launch protection, restart and explicit force kill', () async {
    final app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    repository.saveApplication(app);
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'long',
      applicationId: app.id,
      name: 'Long',
      trustedFingerprint: review.fingerprint,
      arguments: ['-c', 'import time; time.sleep(30)'],
    );
    repository.saveProfile(profile);
    await processes.launch(app, profile);
    expect(processes.isRunning(profile.id), isTrue);
    await expectLater(processes.launch(app, profile), throwsStateError);
    final pid = processes.pidFor(profile.id);
    await processes.restart(app, profile);
    expect(processes.pidFor(profile.id), isNot(pid));
    await processes.stop(profile.id, force: true);
    await settled(profile.id);
    expect(repository.history(profile.id).length, 2);
    expect(repository.history(profile.id).first['exitCode'], -9);
  });

  for (final stopRunning in [false, true]) {
    test(
      'Exit persistence waits for both streams, including ${stopRunning ? 'graceful stop' : 'cross-instance reconciliation'}',
      () async {
        final owner = DrainingProcesses(runtime, repository);
        processes = owner;
        const app = Application(
          id: 'app',
          name: 'Python',
          executable: '/usr/bin/python3',
        );
        final review = await runtime.inspect(app.executable);
        final profile = Profile(
          id: 'draining',
          applicationId: app.id,
          name: 'Draining',
          trustedFingerprint: review.fingerprint,
          arguments: [
            '-c',
            stopRunning
                ? 'import time; print("complete",flush=True); time.sleep(30)'
                : 'print("complete")',
          ],
        );
        repository.saveApplication(app);
        repository.saveProfile(profile);
        await owner.launch(app, profile);
        if (stopRunning) {
          final output = File(
            repository.history(profile.id).single['stdout'] as String,
          );
          for (var attempt = 0; attempt < 100; attempt++) {
            if (await output.exists() &&
                (await output.readAsString()).contains('complete')) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }
        var stopped = false;
        final stopping = stopRunning
            ? owner.stop(profile.id).then((_) => stopped = true)
            : null;
        await owner.captured.future.timeout(const Duration(seconds: 5));
        expect(repository.history(profile.id).single['stop'], isNull);
        if (!stopRunning) {
          LinuxProcesses(runtime, repository).reconcile();
          expect(
            repository.history(profile.id).single['interrupted'],
            isNot(true),
          );
          expect(
            LinuxProcesses(runtime, repository).isRunning(profile.id),
            isTrue,
          );
          expect(
            LinuxProcesses(runtime, repository).pidFor(profile.id),
            isNull,
          );
        }
        await expectLater(
          owner.waitForPendingExits(timeout: const Duration(milliseconds: 20)),
          throwsA(isA<OutputStreamsPending>()),
        );
        await expectLater(
          owner.launch(app, profile),
          throwsA(isA<OutputStreamsPending>()),
        );
        expect(repository.history(profile.id), hasLength(1));
        var drained = false;
        final draining = owner
            .waitForPendingExits(timeout: null)
            .then((_) => drained = true);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(drained, isFalse);
        expect(stopped, stopRunning);
        owner.release.complete();
        await draining;
        await stopping;
        final record = repository.history(profile.id).single;
        expect(record['exitCode'], stopRunning ? -15 : 0);
        expect(record['interrupted'], isFalse);
        expect(
          await File(record['stdout'] as String).readAsString(),
          contains('complete'),
        );
      },
    );
  }

  test('Unknown exit state is reconciled without signaling reused PIDs', () {
    repository.saveProfile(
      const Profile(id: 'x', applicationId: 'app', name: 'X'),
    );
    repository.recordLaunch({
      'id': 'history',
      'profileId': 'x',
      'pid': pid,
      'identity': 'wrong-boot:wrong-start',
      'supervisorPid': pid,
      'supervisorIdentity': 'wrong-boot:wrong-start',
      'supervisionPending': true,
      'stop': null,
    });
    expect(processes.isRunning('x'), isFalse);
    processes.reconcile();
    expect(repository.history('x').first['interrupted'], isTrue);
    expect(repository.history('x').first['supervisionPending'], isFalse);
  });

  test('Desktop entry uses Atyaf profile ID, escaping and valid native desktop format', () async {
    final executable = File(
      '${temporary.path}/Atyaf "quote" dollar\$ percent% slash\\',
    );
    await executable.writeAsString('#!/bin/sh\nexit 0');
    await Process.run('chmod', ['700', '--', executable.path]);
    final entries = LinuxDesktopEntries(
      runtime,
      await File('assets/icon/icon.png').readAsBytes(),
      executable: executable.path,
    );
    const app = Application(
      id: 'app',
      name: 'برنامج\nNotAField=1',
      executable: '/usr/bin/true',
      wmClass: 'Test',
    );
    const profile = Profile(
      id: 'identity-1',
      applicationId: 'app',
      name: 'Work',
    );
    await entries.create(app, profile);
    final file = File(entries.filePath(profile.id));
    final text = await file.readAsString();
    expect(text, contains('--launch-profile "identity-1"'));
    expect(text, isNot(contains('Exec=/usr/bin/true')));
    expect(text, contains('%%'));
    expect(text, contains('StartupWMClass=Test'));
    expect(text, isNot(contains('\nNotAField=')));
    final check = await Process.run('desktop-file-validate', [file.path]);
    expect(check.exitCode, 0, reason: check.stderr.toString());
    await entries.remove(profile.id);
    expect(await file.exists(), isFalse);
  });

  for (final format in ['gz', 'xz', 'zst']) {
    test(
      'Safe tar.$format extraction preserves executable permissions and Unicode names',
      () async {
        final input = Directory('${temporary.path}/input');
        await input.create();
        final executable = File('${input.path}/برنامج with spaces');
        await executable.writeAsString('#!/bin/sh\nexit 0');
        await Process.run('chmod', ['755', '--', executable.path]);
        await Link('${input.path}/safe-link').create('برنامج with spaces');
        final archive = '${temporary.path}/portable.tar.$format';
        final flag = {'gz': '-czf', 'xz': '-cJf', 'zst': '--zstd'}[format]!;
        final args = format == 'zst'
            ? [flag, '-cf', archive, '-C', input.path, '.']
            : [flag, archive, '-C', input.path, '.'];
        final result = await Process.run('tar', args);
        expect(result.exitCode, 0);
        final root = await archives.extractPortable(archive);
        expect(
          (await File('$root/برنامج with spaces').stat()).mode & 0x40,
          isNot(0),
        );
        expect(await Link('$root/safe-link').target(), 'برنامج with spaces');
        expect(
          await runtime.discover(root),
          contains('$root/برنامج with spaces'),
        );
      },
    );
  }

  for (final attack in [
    'traversal',
    'absolute',
    'symlink',
    'symlink-child',
    'hardlink',
    'duplicate',
  ]) {
    test(
      'Extraction rejects $attack and cleans partial managed files',
      () async {
        final archive = '${temporary.path}/malicious.tar.gz';
        final generator = await Process.run('python3', [
          '-c',
          '''
import tarfile,io,sys
with tarfile.open(sys.argv[1],'w:gz') as t:
    attack=sys.argv[2]
    name='../escape' if attack=='traversal' else '/tmp/atyaf-escape' if attack=='absolute' else 'entry'
    m=tarfile.TarInfo(name)
    if attack in ['symlink','symlink-child']:
        m.type=tarfile.SYMTYPE; m.linkname='/tmp' if attack=='symlink' else 'target'
        t.addfile(m)
        if attack=='symlink-child':
            m=tarfile.TarInfo('entry/child'); m.size=1; t.addfile(m,io.BytesIO(b'x'))
    elif attack=='hardlink':
        m.type=tarfile.LNKTYPE; m.linkname='../escape'; t.addfile(m)
    else:
        m.size=1; t.addfile(m,io.BytesIO(b'x'))
        if attack=='duplicate': t.addfile(m,io.BytesIO(b'x'))
''',
          archive,
          attack,
        ]);
        expect(generator.exitCode, 0);
        await expectLater(archives.extractPortable(archive), throwsStateError);
        expect(
          await Directory('${runtime.root}/portable').list().toList(),
          isEmpty,
        );
        expect(await File('${temporary.path}/escape').exists(), isFalse);
      },
    );
  }

  test('Backup round trip restores managed data and metadata without deleting custom data', () async {
    const app = Application(id: 'app', name: 'A', executable: '/usr/bin/true');
    const profile = Profile(id: 'work', applicationId: 'app', name: 'Work');
    repository.saveApplication(app);
    repository.saveProfile(profile);
    await runtime.prepare(profile);
    await File('${runtime.profileRoot(profile.id)}/data/value')
        .writeAsString('preserved');
    final external = File('${temporary.path}/external');
    await external.writeAsString('external');
    final backup = LinuxBackup(runtime, repository, archives, processes);
    final destination = '${temporary.path}/backup.tar.gz';
    await backup.export(destination);
    await File('${runtime.profileRoot(profile.id)}/data/value')
        .writeAsString('changed');
    repository.removeApplication(app.id);
    await backup.restore(destination);
    expect(repository.applications.single.name, 'A');
    expect(repository.profiles.single.trustedFingerprint, '');
    expect(
      await File('${runtime.profileRoot(profile.id)}/data/value')
          .readAsString(),
      'preserved',
    );
    expect(await external.readAsString(), 'external');
  });

  test('Two running profiles write to different isolated data paths', () async {
    const app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    repository.saveApplication(app);
    final review = await runtime.inspect(app.executable);
    for (final id in ['work', 'personal']) {
      final profile = Profile(
        id: id,
        applicationId: app.id,
        name: id,
        trustedFingerprint: review.fingerprint,
        arguments: [
          '-c',
          'import os,time,pathlib; pathlib.Path(os.environ["XDG_DATA_HOME"],"identity").write_text(os.environ["IDENTITY"]); time.sleep(30)',
        ],
        environment: {'IDENTITY': id},
      );
      repository.saveProfile(profile);
      await processes.launch(app, profile);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final id in ['work', 'personal']) {
      expect(processes.isRunning(id), isTrue);
      expect(
        await File('${runtime.profileRoot(id)}/data/identity').readAsString(),
        id,
      );
      await processes.stop(id);
      await settled(id);
    }
    expect(runtime.host.containsKey('IDENTITY'), isFalse);
  });

  test(
    'Complete large streams, bounded previews and canonical log confinement',
    () async {
      const app = Application(
        id: 'app',
        name: 'Python',
        executable: '/usr/bin/python3',
      );
      repository.saveApplication(app);
      final review = await runtime.inspect(app.executable);
      final profile = Profile(
        id: 'large',
        applicationId: app.id,
        name: 'Large',
        trustedFingerprint: review.fingerprint,
        arguments: [
          '-c',
          'import sys; sys.stdout.buffer.write(b"o"*(12*1024*1024)); sys.stderr.buffer.write(b"e"*(12*1024*1024))',
        ],
      );
      repository.saveProfile(profile);
      await processes.launch(app, profile);
      await settled(profile.id);
      final record = repository.history(profile.id).first;
      final stdoutPath = record['stdout'] as String;
      expect(await File(stdoutPath).length(), 12 * 1024 * 1024);
      expect(await File(record['stderr'] as String).length(), 12 * 1024 * 1024);
      final logs = LogService(runtime);
      expect((await logs.read(stdoutPath, profile.id)).length, 256 * 1024);
      final actualRoot = '${temporary.path}/actual-library';
      await Directory(runtime.root).rename(actualRoot);
      await Link(runtime.root).create(actualRoot);
      expect(
        (await logs.read(stdoutPath, profile.id)).startsWith('oooo'),
        isTrue,
      );
      final external = File('${temporary.path}/outside-log');
      await external.writeAsString('outside');
      final escape = '${runtime.profileRoot(profile.id)}/logs/escape.log';
      await Link(escape).create(external.path);
      await expectLater(
        logs.validatedFile(escape, profile.id),
        throwsArgumentError,
      );
    },
  );

  test('Nonzero exit records crash state and stderr', () async {
    const app = Application(
      id: 'app',
      name: 'Python',
      executable: '/usr/bin/python3',
    );
    repository.saveApplication(app);
    final review = await runtime.inspect(app.executable);
    final profile = Profile(
      id: 'crash',
      applicationId: app.id,
      name: 'Crash',
      trustedFingerprint: review.fingerprint,
      arguments: [
        '-c',
        'import sys; print("failure",file=sys.stderr); sys.exit(7)',
      ],
    );
    repository.saveProfile(profile);
    await processes.launch(app, profile);
    await settled(profile.id);
    expect(repository.history(profile.id).first['exitCode'], 7);
    expect(repository.history(profile.id).first['crashed'], isTrue);
  });

  test('Host bridge reports real PID, exact Unicode environment and validates signal identity', () async {
    final directory = Directory(runtime.profileRoot('bridge'));
    await directory.create(recursive: true);
    final request = File('${directory.path}/request.json');
    final status = File('${directory.path}/status.json');
    await request.writeAsString(
      jsonEncode({
        'executable': '/usr/bin/python3',
        'arguments': [
          '-c',
          'import os,sys,json,time; print(json.dumps([sys.argv[1:],os.environ["VALUE"]],ensure_ascii=False),flush=True); time.sleep(30)',
          r'Unicode العربية ;$(false)',
        ],
        'workingDirectory': temporary.path,
        'environment': {...Platform.environment, 'VALUE': r'قيمة ;$(false)'},
        'status': status.path,
      }),
    );
    final helper = File('assets/linux/process_helper.py').absolute.path;
    final process = await Process.start('/usr/bin/python3', [
      helper,
      'launch',
      request.path,
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    for (var i = 0; i < 100 && !await status.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final state = jsonDecode(await status.readAsString()) as Map;
    expect(state['pid'], isNot(process.pid));
    expect(state['identity'], LinuxProcesses.identity(state['pid'] as int));
    final rejected = await Process.run('/usr/bin/python3', [
      helper,
      'signal',
      '${state['pid']}',
      'wrong-identity',
      'force',
    ]);
    expect(rejected.exitCode, 1);
    expect(LinuxProcesses.identity(state['pid'] as int), state['identity']);
    final signaled = await Process.run('/usr/bin/python3', [
      helper,
      'signal',
      '${state['pid']}',
      state['identity'] as String,
      'graceful',
    ]);
    expect(signaled.exitCode, 0);
    expect(await process.exitCode, 143);
    final decoded = jsonDecode((await output).trim()) as List;
    expect(decoded[0], [r'Unicode العربية ;$(false)']);
    expect(decoded[1], r'قيمة ;$(false)');
    expect(await errors, isEmpty);
    expect((jsonDecode(await status.readAsString()) as Map)['exitCode'], -15);
  });
}
