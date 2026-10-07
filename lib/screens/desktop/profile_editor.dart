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
    this.hasX11Display = false,
  });
  final String applicationId;
  final Future<void> Function(Profile) saveProfile;
  final Profile? profile;
  final bool hasX11Display;
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

  Future<void> useSecretService() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.useSecretService),
        content: SingleChildScrollView(child: Text(l.secretServiceConfirm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.next),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final args = List<String>.from(jsonDecode(arguments.text) as List);
      final kept = <String>[];
      final separator = args.indexOf('--');
      final options = separator < 0 ? args : args.sublist(0, separator);
      final positional = separator < 0 ? <String>[] : args.sublist(separator);
      for (var index = 0; index < options.length; index++) {
        if (options[index] == '--password-store') {
          // Replace both supported command-line forms, not unrelated flags.
          if (index + 1 < options.length &&
              !options[index + 1].startsWith('--')) {
            index++;
          }
        } else if (!options[index].startsWith('--password-store=')) {
          kept.add(options[index]);
        }
      }
      arguments.text = jsonEncode([
        ...kept,
        '--password-store=gnome-libsecret',
        ...positional,
      ]);
      setState(() => error = null);
    } catch (_) {
      setState(() => error = l.invalidInput);
    }
  }

  Future<void> useX11WindowControls() async {
    if (!widget.hasX11Display) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.useX11WindowControls),
        content: SingleChildScrollView(child: Text(l.x11WindowControlsConfirm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.next),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final env = Map<String, String>.from(jsonDecode(environment.text) as Map);
      env['GDK_BACKEND'] = 'x11';
      environment.text = jsonEncode(env);
      setState(() => error = null);
    } catch (_) {
      setState(() => error = l.invalidInput);
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
        const SizedBox(height: 12),
        Text(l.windowControlsHelp),
        const SizedBox(height: 24),
        field(name, l.name),
        field(arguments, l.arguments, lines: 3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: useSecretService,
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(l.useSecretService),
          ),
        ),
        const SizedBox(height: 18),
        field(environment, l.environment, lines: 3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Tooltip(
            message: widget.hasX11Display
                ? l.windowControlsHelp
                : l.x11Unavailable,
            child: OutlinedButton.icon(
              onPressed: widget.hasX11Display ? useX11WindowControls : null,
              icon: const Icon(Icons.desktop_windows_outlined),
              label: Text(l.useX11WindowControls),
            ),
          ),
        ),
        const SizedBox(height: 18),
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
