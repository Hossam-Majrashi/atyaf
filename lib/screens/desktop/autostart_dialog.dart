import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_localizations.dart';
import '../../features/desktop_entries/services/login_arguments.dart';
import '../../features/home/services/library_controller.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/desktop_content.dart';

class AutostartDialog extends StatefulWidget {
  const AutostartDialog({
    super.key,
    required this.library,
    required this.profile,
  });
  final LibraryController library;
  final Profile profile;

  @override
  State<AutostartDialog> createState() => _AutostartDialogState();
}

class _AutostartDialogState extends State<AutostartDialog> {
  final arguments = TextEditingController();
  bool busy = true,
      enabled = false,
      minimized = false,
      invalidArguments = false;
  List<String> savedArguments = const [];
  String? error, notice;

  bool get changed => minimized
      ? savedArguments.isEmpty ||
            arguments.text.trim() != jsonEncode(savedArguments)
      : savedArguments.isNotEmpty;

  @override
  void initState() {
    super.initState();
    run(load);
  }

  @override
  void dispose() {
    arguments.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final current = await widget.library.autostart!.autostartArguments(
      widget.profile.id,
    );
    if (mounted) update(current);
  }

  void update(List<String>? current, {String? message}) {
    setState(() {
      enabled = current != null;
      savedArguments = current ?? const [];
      minimized = savedArguments.isNotEmpty;
      arguments.text = minimized ? jsonEncode(savedArguments) : '';
      invalidArguments = false;
      notice = message;
    });
  }

  void setMinimized(bool? value) {
    setState(() {
      minimized = value == true;
      invalidArguments = false;
      notice = null;
      if (minimized && arguments.text.isEmpty) {
        final app = widget.library.repository.applications
            .where((app) => app.id == widget.profile.applicationId)
            .firstOrNull;
        if (app == null) return;
        // Suggest only known app-specific flags, and keep them editable.
        String appKey(String name) =>
            name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final identities = [
          appKey(app.name),
          appKey(p.basenameWithoutExtension(app.executable)),
        ];
        if (identities.contains('vesktop')) {
          arguments.text = jsonEncode(['--start-minimized']);
        } else if (identities.contains('misterdownloadmanager')) {
          arguments.text = jsonEncode(['/startup']);
        }
      }
    });
  }

  Future<void> run(Future<void> Function() operation) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await operation();
    } catch (failure, stack) {
      widget.library.reportError(failure, stack);
      if (mounted) {
        setState(
          () => error = AppLocalizations.of(context).error(failure.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(bool next) async {
    var flags = const <String>[];
    if (next && minimized) {
      try {
        flags = LoginArguments.parse(arguments.text);
      } on FormatException {
        setState(() {
          invalidArguments = true;
          notice = null;
        });
        return;
      }
    }
    await run(() async {
      await widget.library.repository.withExclusiveLock(() async {
        final current = widget.library.repository.profiles.firstWhere(
          (p) =>
              p.id == widget.profile.id &&
              p.applicationId == widget.profile.applicationId,
        );
        await widget.library.autostart!.setAutostart(
          current,
          next,
          loginArguments: flags,
        );
      });
      if (mounted) {
        update(next ? flags : null, message: AppLocalizations.of(context).done);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editable = !busy && error == null;
    return DesktopDialog(
      title: l.autostart,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        if (enabled && changed)
          TextButton(
            onPressed: editable ? () => save(false) : null,
            child: Text(l.disableAutostart),
          ),
        FilledButton(
          onPressed: editable ? () => save(!enabled || changed) : null,
          child: Text(
            !enabled
                ? l.enableAutostart
                : (changed ? l.save : l.disableAutostart),
          ),
        ),
      ],
      children: [
        Text(
          widget.profile.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (busy)
          const LinearProgressIndicator()
        else
          Text(enabled ? l.autostartEnabled : l.autostartDisabled),
        CheckboxListTile(
          title: Text(l.autostartMinimized),
          subtitle: Text(l.autostartMinimizedHelp),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: minimized,
          onChanged: editable ? setMinimized : null,
        ),
        if (minimized)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: arguments,
              enabled: editable,
              minLines: 1,
              maxLines: 3,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.autostartArguments,
                errorText: invalidArguments
                    ? l.autostartArgumentsInvalid
                    : null,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {
                invalidArguments = false;
                notice = null;
              }),
            ),
          ),
        if (notice != null) ...[Text(notice!), const SizedBox(height: 16)],
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: busy ? null : () => run(load),
            child: Text(l.retry),
          ),
        ],
        const SizedBox(height: 8),
        Text(l.autostartHelp),
        const SizedBox(height: 16),
        Text(l.autostartIsolationHelp),
      ],
    );
  }
}
