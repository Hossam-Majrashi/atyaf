import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// fcntl.lockf is the POSIX record-lock family used by Dart on Linux (not flock).
Future<Process> holdLock(String path) async {
  final process = await Process.start('/usr/bin/python3', [
    '-c',
    'import fcntl,sys; f=open(sys.argv[1],"a"); '
        'fcntl.lockf(f,fcntl.LOCK_EX); print("locked",flush=True); '
        'sys.stdin.readline()',
    path,
  ]);
  await process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  return process;
}

Future<void> releaseLock(Process process) async {
  process.stdin.writeln();
  await process.stdin.close();
  expect(await process.exitCode, 0);
}
