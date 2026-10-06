import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/desktop_content.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.applicationId,
    required this.saveProfile,
    this.profile,
    this.onError,
  });
  final String applicationId;
  final Future<void> Function(Profile) saveProfile;
  final Profile? profile;
  final void Function(Object, StackTrace)? onError;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final name = TextEditingController(text: widget.profile?.name);
  late final arguments = TextEditingController(
    text: jsonEncode(widget.profile?.arguments ?? []),
  );
  late final environment = TextEditingController(
    text: jsonEncode(widget.profile?.environment ?? {}),
  );
  late final working = TextEditingController(
    text: widget.profile?.workingDirectory,
  );
  late final paths = {
    for (final key in ['config', 'data', 'cache', 'state', 'temp', 'home'])
      key: TextEditingController(text: widget.profile?.paths[key] ?? ''),
  };
  String? error;
  @override
  void dispose() {
    for (final controller in [
      name,
      arguments,
      environment,
      working,
      ...paths.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    try {
      final args = List<String>.from(jsonDecode(arguments.text) as List);
      final env = Map<String, String>.from(jsonDecode(environment.text) as Map);
      if (name.text.trim().isEmpty) {
        throw const FormatException();
      }
      final profile = Profile(
        id: widget.profile?.id ?? const Uuid().v4(),
        applicationId: widget.applicationId,
        name: name.text.trim(),
        arguments: args,
        environment: env,
        workingDirectory: working.text,
        paths: {for (final e in paths.entries) e.key: e.value.text},
        trustedFingerprint: widget.profile?.trustedFingerprint ?? '',
      );
      await widget.saveProfile(profile);
      if (mounted) {
        Navigator.pop(context, profile);
      }
    } catch (failure, stack) {
      if (failure is! FormatException &&
          failure is! TypeError &&
          failure is! ArgumentError) {
        widget.onError?.call(failure, stack);
      }
      if (mounted) {
        setState(() => error = AppLocalizations.of(context).invalidInput);
      }
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines + 2,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = {
      'config': l.configPath,
      'data': l.dataPath,
      'cache': l.cachePath,
      'state': l.statePath,
      'temp': l.tempPath,
      'home': l.homePath,
    };
    return DesktopDialog(
      title: widget.profile == null ? l.newProfile : l.edit,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: save, child: Text(l.save)),
      ],
      children: [
        Text(l.profileHelp),
        const SizedBox(height: 12),
        Text(l.tempHelp),
        const SizedBox(height: 24),
        field(name, l.name),
        field(arguments, l.arguments, lines: 3),
        field(environment, l.environment, lines: 3),
        field(working, l.workingDirectory),
        for (final e in paths.entries) field(e.value, labels[e.key]!),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
