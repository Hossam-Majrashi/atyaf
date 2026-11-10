import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
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
  bool busy = true, enabled = false;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    run(() async {
      final value = await widget.library.autostart!.autostartEnabled(
        widget.profile.id,
      );
      if (mounted) setState(() => enabled = value);
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

  Future<void> save() => run(() async {
    final next = !enabled;
    await widget.library.repository.withExclusiveLock(() async {
      final current = widget.library.repository.profiles.firstWhere(
        (p) =>
            p.id == widget.profile.id &&
            p.applicationId == widget.profile.applicationId,
      );
      await widget.library.autostart!.setAutostart(current, next);
    });
    if (mounted) {
      setState(() {
        enabled = next;
        notice = AppLocalizations.of(context).done;
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DesktopDialog(
      title: l.autostart,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        FilledButton(
          onPressed: busy || error != null ? null : save,
          child: Text(enabled ? l.disableAutostart : l.enableAutostart),
        ),
      ],
      children: [
        Text(
          widget.profile.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Text(l.autostartHelp),
        const SizedBox(height: 16),
        Text(l.autostartIsolationHelp),
        const SizedBox(height: 16),
        if (busy)
          const LinearProgressIndicator()
        else
          Text(enabled ? l.autostartEnabled : l.autostartDisabled),
        if (notice != null) ...[const SizedBox(height: 16), Text(notice!)],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => run(() async {
              final value = await widget.library.autostart!.autostartEnabled(
                widget.profile.id,
              );
              if (mounted) setState(() => enabled = value);
            }),
            child: Text(l.retry),
          ),
        ],
      ],
    );
  }
}
