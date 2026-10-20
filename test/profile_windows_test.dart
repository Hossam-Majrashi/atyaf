import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Linux profile window ownership, shortcut and activation boundaries',
    () async {
      final result = await Process.run('/usr/bin/python3', [
        'test/profile_windows_test.py',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}
