import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux release validation rejects wrong architectures and incomplete assets', () async {
    final result = await Process.run('python3', [
      'test/release_validation_test.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
  for (final script in ['build_linux.sh', 'flatpak_linux.sh']) {
    for (final arch in ['armv7', 'i686']) {
      test(
        '$script explicitly refuses unsupported $arch without building',
        () async {
          final temporary = await Directory.systemTemp.createTemp(
            'atyaf unsupported arch ',
          );
          try {
            final copy = await File(script).copy('${temporary.path}/$script');
            final result = await Process.run('bash', [copy.path, arch]);
            expect(result.exitCode, 1);
            expect(
              result.stderr.toString(),
              contains('32-bit builds are unsupported'),
            );
            expect(await Directory('${temporary.path}/dist').exists(), isFalse);
            expect(
              await Directory('${temporary.path}/build').exists(),
              isFalse,
            );
          } finally {
            await temporary.delete(recursive: true);
          }
        },
      );
    }
  }
  for (final architecture in {'x64': 'x86_64', 'arm64': 'aarch64'}.entries) {
    for (final existingBuild in [false, true]) {
      test(
        'Native packaging initializes ${architecture.key} workspace with build ${existingBuild ? 'present' : 'absent after clean'}',
        () async {
          final temporary = await Directory.systemTemp.createTemp(
            'atyaf packaging space ',
          );
          try {
            final project = await Directory('${temporary.path}/project')
                .create();
            final tools = await Directory('${temporary.path}/tools').create();
            final script = await File('build_linux.sh')
                .copy('${project.path}/build_linux.sh');
            await File('${project.path}/pubspec.yaml')
                .writeAsString('version: 1.1.0+1\n');
            final build = Directory('${project.path}/build');
            final sentinel = File('${build.path}/keep');
            if (existingBuild) {
              await build.create();
              await sentinel.writeAsString('existing build data');
            }
            // Satisfy preflight without running packaging tools. The test uses
            // real Bash/mkdir/mktemp/rm and stops at the Flutter invocation.
            for (final name in [
              'flutter',
              'dpkg-deb',
              'rpmbuild',
              'bsdtar',
              'zstd',
              'tar',
              'gzip',
              'install',
              'readelf',
              'ldd',
              'desktop-file-validate',
              'appstreamcli',
              'appimagetool',
              'zsyncmake',
              'curl',
              'cp',
              'mv',
              'ln',
              'tee',
              'grep',
              'date',
              'du',
              'awk',
              'uname',
            ]) {
              final tool = File('${tools.path}/$name');
              final body = switch (name) {
                'uname' => 'printf "%s\\n" "${architecture.value}"\n',
                'flutter' =>
                  '''
[[ "\$*" == "build linux --release --target-platform linux-${architecture.key}" ]] || exit 90
shopt -s nullglob
work=("\$PWD"/build/package-${architecture.key}.*)
[[ \${#work[@]} == 1 && -d "\${work[0]}" && -d "\$PWD/dist" ]] || exit 91
printf '%s' "\${work[0]}" > flutter-reached
exit 73
''',
                _ => 'exit 92\n',
              };
              await tool.writeAsString('#!/bin/bash\nset -euo pipefail\n$body');
              final chmod = await Process.run('chmod', ['700', tool.path]);
              expect(chmod.exitCode, 0);
            }
            final result = await Process.run(
              'bash',
              [script.path, architecture.key],
              workingDirectory: temporary.path,
              environment: {
                'PATH': '${tools.path}:${Platform.environment['PATH']}',
              },
            );
            expect(result.exitCode, 73, reason: result.stderr.toString());
            expect(result.stderr.toString(), isNot(contains('mktemp:')));
            final workspace = await File('${project.path}/flutter-reached')
                .readAsString();
            expect(
              workspace,
              startsWith('${build.path}/package-${architecture.key}.'),
            );
            // The EXIT trap cleans only this invocation's private workspace.
            expect(await Directory(workspace).exists(), isFalse);
            expect(await build.exists(), isTrue);
            expect(await Directory('${project.path}/dist').exists(), isTrue);
            if (existingBuild) {
              expect(await sentinel.readAsString(), 'existing build data');
            } else {
              expect(await build.list().toList(), isEmpty);
            }
          } finally {
            await temporary.delete(recursive: true);
          }
        },
      );
    }
  }
}
