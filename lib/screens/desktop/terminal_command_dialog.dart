import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/desktop_entries/services/terminal_command_service.dart';
import '../../features/home/services/library_controller.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/desktop_content.dart';

class TerminalCommandDialog extends StatefulWidget {
  const TerminalCommandDialog({
    super.key,
    required this.library,
    required this.profile,
  });
  final LibraryController library;
  final Profile profile;
  @override
  State<TerminalCommandDialog> createState() => _TerminalCommandDialogState();
}

class _TerminalCommandDialogState extends State<TerminalCommandDialog> {
  late final name = TextEditingController(text: suggestedName());
  List<TerminalCommand> commands = [];
  TerminalCommand? created;
  String? error, notice;
  bool busy = true;
  TerminalCommandService get service => widget.library.terminalCommands!;

  String suggestedName() {
    final value = widget.profile.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^[^a-z]+|[-.]+$'), '');
    return value.isEmpty
        ? 'app-${widget.profile.id.substring(0, widget.profile.id.length.clamp(0, 8))}'
        : value.substring(0, value.length.clamp(0, 64));
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } on TerminalCommandFailure catch (failure) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(
        () => error = switch (failure.code) {
          'invalid' => l.terminalCommandInvalid,
          'conflict' => l.terminalCommandConflict(failure.detail),
          _ => l.terminalCommandUnsafe(failure.detail),
        },
      );
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

  Future<void> load() => run(() async {
    final existing = await service.terminalCommands(widget.profile.id);
    if (mounted) setState(() => commands = existing);
  });

  Future<void> create() => run(() async {
    final l = AppLocalizations.of(context);
    final result = await widget.library.repository.withExclusiveLock(() async {
      if (!widget.library.repository.profiles.any(
        (item) =>
            item.id == widget.profile.id &&
            item.applicationId == widget.profile.applicationId,
      )) {
        throw StateError('Profile no longer exists');
      }
      return service.createTerminalCommand(
        widget.profile.id,
        name.text.trim(),
        argumentsWarning: l.terminalArgumentsHelp,
      );
    });
    final existing = await service.terminalCommands(widget.profile.id);
    if (mounted) {
      setState(() {
        created = result;
        commands = existing;
      });
    }
  });

  Future<void> remove() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeTerminalCommands),
        content: Text(l.removeTerminalCommandsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await run(() async {
      final preserved = await widget.library.repository.withExclusiveLock(
        () => service.removeTerminalCommands(widget.profile.id),
      );
      if (mounted) {
        setState(() {
          commands = [];
          created = null;
          notice = preserved.isEmpty
              ? l.terminalCommandsRemoved
              : l.terminalCommandsPreserved(preserved.join(', '));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DesktopDialog(
      title: l.terminalCommand,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
        FilledButton(
          onPressed: busy ? null : create,
          child: Text(l.createTerminalCommand),
        ),
      ],
      children: [
        Text(l.terminalCommandHelp),
        const SizedBox(height: 16),
        Text(
          widget.profile.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          enabled: !busy,
          onChanged: (_) => setState(() {
            error = null;
            created = null;
          }),
          decoration: InputDecoration(
            labelText: l.terminalCommandName,
            helperText: l.terminalCommandInvalid,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(l.terminalArgumentsHelp),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (created case final command?) ...[
          const SizedBox(height: 20),
          Text(l.terminalCommandCreated(command.name)),
          SelectableText(command.name),
          SelectableText(command.path),
          if (!command.inPath) ...[
            const SizedBox(height: 12),
            Text(l.terminalPathMissing),
            SelectableText(l.terminalPathCommand),
          ],
        ],
        if (commands.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l.existingTerminalCommands),
          for (final command in commands) SelectableText(command.path),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: busy ? null : remove,
              child: Text(l.removeTerminalCommands),
            ),
          ),
        ],
        if (notice != null) ...[const SizedBox(height: 16), Text(notice!)],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
