import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/services/crash_diagnostics.dart';

import '../../../shared/services/runtime_service.dart';

class ReportSection {
  const ReportSection(
    this.title, {
    this.text = '',
    this.logPath,
    this.profileId,
  });
  final String title, text;
  final String? logPath, profileId;
}

class ReportTooLarge implements Exception {}

class LogService {
  LogService(this.runtime, {this.diagnostics});
  final RuntimeService runtime;
  final CrashDiagnostics? diagnostics;
  static String previewText(String text) {
    final bytes = utf8.encode(text);
    return utf8.decode(
      bytes.length > 256 * 1024 ? bytes.sublist(0, 256 * 1024) : bytes,
      allowMalformed: true,
    );
  }

  Future<String> coreInfo(Map<String, dynamic> record) async =>
      await diagnostics?.info(record) ?? '';

  Stream<List<int>> reportBytes(List<ReportSection> sections) async* {
    for (final section in sections) {
      yield utf8.encode('${section.title}\n');
      if (section.logPath != null) {
        final file = await validatedFile(section.logPath!, section.profileId!);
        if (file == null) {
          yield utf8.encode(section.text);
        } else {
          await for (final text in file.openRead().transform(
            const Utf8Decoder(allowMalformed: true),
          )) {
            yield utf8.encode(text);
          }
        }
      } else {
        yield utf8.encode(section.text);
      }
      yield utf8.encode('\n\n');
    }
  }

  Future<String> completeReport(
    List<ReportSection> sections, {
    int clipboardLimit = 64 * 1024 * 1024,
  }) async {
    final result = StringBuffer();
    var size = 0;
    await for (final bytes in reportBytes(sections)) {
      size += bytes.length;
      if (size > clipboardLimit) throw ReportTooLarge();
      result.write(utf8.decode(bytes));
    }
    return result.toString();
  }

  Future<void> exportReport(
    List<ReportSection> sections,
    String destination,
  ) async {
    if (!p.isAbsolute(destination) || destination.contains('\x00')) {
      throw ArgumentError('Report destination must be absolute');
    }
    final root = await Directory(runtime.root).resolveSymbolicLinks();
    final parent = await Directory(p.dirname(destination))
        .resolveSymbolicLinks();
    final target = p.join(parent, p.basename(destination));
    if (p.equals(root, target) || p.isWithin(root, target)) {
      throw ArgumentError('Reports must not overwrite managed library files');
    }
    // mkdtemp creates a 0700 directory before any report file is opened.
    final staging = await Directory(parent).createTemp('.atyaf-report-');
    final temporary = File('${staging.path}/report.txt');
    try {
      await temporary.create(exclusive: true);
      final chmod = await Process.run('/usr/bin/chmod', [
        '600',
        '--',
        temporary.path,
      ]);
      if (chmod.exitCode != 0) {
        throw FileSystemException(chmod.stderr.toString(), temporary.path);
      }
      final sink = temporary.openWrite();
      try {
        await for (final bytes in reportBytes(sections)) {
          sink.add(bytes);
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      await temporary.rename(target);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<File?> validatedFile(String path, String profileId) async {
    final expected = p.join(runtime.profileRoot(profileId), 'logs');
    if (!p.isWithin(expected, path)) {
      throw ArgumentError('Invalid log path');
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final root = await Directory(runtime.root).resolveSymbolicLinks();
    final directory = await Directory(expected).resolveSymbolicLinks();
    final canonical = await file.resolveSymbolicLinks();
    if (!p.isWithin(root, directory) || !p.isWithin(directory, canonical)) {
      throw ArgumentError('External log path');
    }
    return File(canonical);
  }

  Future<bool> openComplete(String path, String profileId) async {
    final file = await validatedFile(path, profileId);
    if (file == null) return false;
    return launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
  }

  Future<String> read(String path, String profileId) async {
    final file = await validatedFile(path, profileId);
    if (file == null) return '';
    final bytes = await file.open();
    try {
      return utf8.decode(await bytes.read(256 * 1024), allowMalformed: true);
    } finally {
      await bytes.close();
    }
  }
}
