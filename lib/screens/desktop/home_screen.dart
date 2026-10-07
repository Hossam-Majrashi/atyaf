import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../shared/services/managed_storage_service.dart';
import '../../features/updates/services/update_service.dart';
import '../../features/settings/services/preferences_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/desktop_content.dart';
import 'logs_screen.dart';
import 'errors_screen.dart';
import 'application_editor.dart';
import 'application_icon_picker.dart';
import 'application_icon_image.dart';
import 'profile_editor.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.library,
    required this.preferences,
    this.launchProfileId,
  });
  final LibraryController library;
  final PreferencesService preferences;
  final String? launchProfileId;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool busy = false;
  LibraryController get library => widget.library;
  @override
  void initState() {
    super.initState();
    if (widget.launchProfileId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => perform(() async {
          final profile = library.repository.profiles.firstWhere(
            (v) => v.id == widget.launchProfileId,
          );
          library.select(profile.applicationId);
          await launch(profile);
        }),
      );
    }
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await operation();
      library.refresh();
    } on ApplicationRunning {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).updateRunning)),
        );
      }
    } catch (error, stack) {
      library.reportError(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).error(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> confirm(String title, String message) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(title),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> nameDialog(String initial) => showDialog<String>(
    context: context,
    builder: (_) => _ApplicationNameDialog(initial: initial),
  );

  Future<String?> chooseExecutable(ManagedSource source) async {
    final files = source.executables;
    final reviews = <ExecutableReview>[];
    for (final relative in files) {
      reviews.add(await library.storage.review(source, relative));
    }
    if (!mounted) {
      return null;
    }
    final l = AppLocalizations.of(context);
    if (files.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.noExecutables)));
      return null;
    }
    return showDialog<String>(
      context: context,
      builder: (context) => DesktopDialog(
        title: l.chooseExecutable,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
        ],
        children: [
          for (var index = 0; index < files.length; index++)
            ListTile(
              leading: const Icon(Icons.terminal_rounded),
              title: Text(files[index]),
              subtitle: Text(
                l.executableCandidate(
                  files[index],
                  reviews[index].size,
                  reviews[index].mode,
                ),
              ),
              onTap: () => Navigator.pop(context, files[index]),
            ),
        ],
      ),
    );
  }

  Future<void> add(String kind) async {
    final l = AppLocalizations.of(context);
    String? executable;
    ManagedSource? staged;
    try {
      if (kind == 'folder') {
        final directory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: l.folder,
        );
        if (directory == null) {
          return;
        }
        staged = await library.storage.stage(directory, archive: false);
        executable = await chooseExecutable(staged);
      } else {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: kind == 'archive' ? l.archive : l.executable,
        );
        final path = result?.files.single.path;
        if (path == null) {
          return;
        }
        if (kind == 'archive') {
          staged = await library.storage.stage(path, archive: true);
          executable = await chooseExecutable(staged);
        } else {
          executable = path;
        }
      }
      if (executable == null || !mounted) {
        return;
      }
      if (staged == null) {
        await library.runtime.inspect(executable);
      }
      if (!mounted) {
        return;
      }
      final selectedIcon = await showDialog<String>(
        context: context,
        builder: (_) => ApplicationIconPicker(
          root: staged?.root ?? p.dirname(executable!),
          entries: library.entries,
        ),
      );
      if (selectedIcon == null || !mounted) {
        return;
      }
      final iconPng = selectedIcon.isEmpty ? null : selectedIcon;
      final name = await nameDialog(p.basename(executable));
      if (name == null) {
        return;
      }
      final app = staged == null
          ? await library.applicationsService.add(
              name,
              executable,
              iconPng: iconPng,
            )
          : await library.applicationsService.addManaged(
              name,
              staged,
              executable,
              iconPng: iconPng,
            );
      library.select(app.id);
    } finally {
      if (staged != null) {
        await library.storage.discard(staged);
      }
    }
  }

  Future<void> updateApplication(Application app) async {
    final l = AppLocalizations.of(context);
    if (library.updates.isRunning(app)) {
      if (!await confirm(l.stop, l.updateRunning)) {
        return;
      }
      for (final profile in library.repository.profiles.where(
        (item) => item.applicationId == app.id,
      )) {
        if (library.processes.isRunning(profile.id)) {
          await library.processes.stop(profile.id);
        }
      }
      if (library.updates.isRunning(app)) {
        throw ApplicationRunning();
      }
    }
    if (!mounted) {
      return;
    }
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => DesktopDialog(
        title: l.updateSource,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
        ],
        children: [
          Text(l.updateHelp),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: Text(l.folder),
            onTap: () => Navigator.pop(context, 'folder'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l.archive),
            onTap: () => Navigator.pop(context, 'archive'),
          ),
        ],
      ),
    );
    if (kind == null) {
      return;
    }
    final String? path;
    if (kind == 'folder') {
      path = await FilePicker.platform.getDirectoryPath(dialogTitle: l.folder);
    } else {
      path = (await FilePicker.platform.pickFiles(dialogTitle: l.archive))
          ?.files
          .single
          .path;
    }
    if (path == null) {
      return;
    }
    final sourcePath = path;
    final staged = await library.storage.stage(
      sourcePath,
      archive: kind == 'archive',
    );
    try {
      final relative =
          library.updates.preferredExecutable(app, staged) ??
          await chooseExecutable(staged);
      if (relative == null || !mounted) {
        return;
      }
      await library.storage.review(staged, relative);
      if (!mounted) {
        return;
      }
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => DesktopDialog(
          title: l.updateSummary,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.update),
            ),
          ],
          children: [
            Text(l.source, style: Theme.of(context).textTheme.titleMedium),
            SelectableText(p.basename(sourcePath)),
            SelectableText(sourcePath),
            const SizedBox(height: 20),
            Text(l.executable, style: Theme.of(context).textTheme.titleMedium),
            SelectableText(relative),
            const SizedBox(height: 20),
            Text(l.updateHelp),
          ],
        ),
      );
      if (allowed != true) {
        return;
      }
      await library.updates.update(app, staged, relative);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.updateSuccess)));
      }
    } finally {
      await library.storage.discard(staged);
    }
  }

  Future<void> editProfile([Profile? existing]) async {
    final app = library.selected;
    if (app == null) {
      return;
    }
    await showDialog<Profile>(
      context: context,
      builder: (context) => ProfileEditor(
        applicationId: app.id,
        hasX11Display: library.runtime.hasX11Display,
        profile: existing,
        saveProfile: (profile) async {
          await library.profilesService.save(profile);
          await library.entries.create(app, profile);
        },
        onError: library.reportError,
      ),
    );
  }

  Future<void> launch(Profile profile, {bool restart = false}) async {
    final app = library.repository.applications.firstWhere(
      (v) => v.id == profile.applicationId,
    );
    final review = await library.launcher.approval(profile, app);
    if (!mounted) {
      return;
    }
    if (review != null) {
      final l = AppLocalizations.of(context);
      final allowed = await showDialog<bool>(
        context: context,
        builder: (context) => DesktopDialog(
          title: l.securityTitle,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.trustLaunch),
            ),
          ],
          children: [
            Text(l.securityWarning),
            const SizedBox(height: 24),
            SelectableText(
              l.fileReview(review.path, review.owner, review.size, review.mode),
            ),
          ],
        ),
      );
      if (allowed != true) {
        return;
      }
    }
    await library.launcher.launch(
      profile,
      app,
      approval: review,
      restart: restart,
    );
  }

  Widget applicationList(AppLocalizations l) => ListView(
    children: [
      for (final app in library.applications)
        Padding(
          key: ValueKey(app.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            selected: library.selected?.id == app.id,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: app.iconPng == null
                ? Icon(
                    app.portableRoot == null
                        ? Icons.apps_rounded
                        : Icons.inventory_2_outlined,
                  )
                : ApplicationIconImage(
                    encoded: app.iconPng!,
                    width: 36,
                    height: 36,
                  ),
            title: Text(app.name, overflow: TextOverflow.ellipsis),
            onTap: () => library.select(app.id),
          ),
        ),
    ],
  );
  Widget profileCard(Profile profile, AppLocalizations l) {
    final running = library.processes.isRunning(profile.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l.edit,
                  enabled: !busy,
                  onSelected: (action) {
                    if (action == 'logs') {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LogsScreen(library: library, profile: profile),
                        ),
                      );
                      return;
                    }
                    perform(() async {
                      switch (action) {
                        case 'edit':
                          await editProfile(profile);
                        case 'delete':
                          if (await confirm(l.delete, l.deleteConfirm)) {
                            await library.deleteProfile(profile);
                          }
                        case 'shortcut':
                          await createShortcut(profile);
                        case 'removeShortcut':
                          await library.entries.remove(profile.id);
                          notifyDone();
                        case 'force':
                          if (await confirm(l.forceKill, l.forceConfirm)) {
                            await library.processes.stop(
                              profile.id,
                              force: true,
                            );
                          }
                      }
                    });
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l.edit)),
                    PopupMenuItem(value: 'logs', child: Text(l.logs)),
                    PopupMenuItem(value: 'shortcut', child: Text(l.shortcut)),
                    PopupMenuItem(
                      value: 'removeShortcut',
                      child: Text(l.removeShortcut),
                    ),
                    if (running)
                      PopupMenuItem(value: 'force', child: Text(l.forceKill)),
                    if (!running)
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              running ? l.running : l.stopped,
              style: TextStyle(
                color: running ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => perform(
                          () => running
                              ? library.processes.stop(profile.id)
                              : launch(profile),
                        ),
                  icon: Icon(
                    running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(running ? l.stop : l.launch),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => perform(() => createShortcut(profile)),
                  icon: const Icon(Icons.app_shortcut_rounded),
                  label: Text(l.shortcut),
                ),
                if (running)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => perform(() => launch(profile, restart: true)),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(l.restart),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> createShortcut(Profile profile) async {
    final application = library.repository.applications.firstWhere(
      (application) => application.id == profile.applicationId,
    );
    await library.entries.create(application, profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).shortcutUpdated)),
      );
    }
  }

  void notifyDone() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).done)),
      );
    }
  }

  Widget profilePanel(AppLocalizations l) {
    final app = library.selected;
    if (app == null) {
      return Center(child: Text(l.selectApplication));
    }
    return ListView(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Text(
              app.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            PopupMenuButton<String>(
              tooltip: l.edit,
              enabled: !busy,
              onSelected: (value) => perform(() async {
                if (value == 'delete') {
                  if (await confirm(l.delete, l.deleteConfirm)) {
                    await library.deleteApplication(app);
                  }
                } else if (value == 'update') {
                  await updateApplication(app);
                } else {
                  final updated = await showDialog<Application>(
                    context: context,
                    builder: (context) => ApplicationEditor(
                      application: app,
                      entries: library.entries,
                    ),
                  );
                  if (updated != null) {
                    final review = await library.runtime.inspect(
                      updated.executable,
                    );
                    final saved = Application(
                      id: updated.id,
                      name: updated.name,
                      executable: review.path,
                      portableRoot: updated.portableRoot,
                      executableRelative: updated.executableRelative,
                      wmClass: updated.wmClass,
                      iconPng: updated.iconPng,
                    );
                    await library.repository.withExclusiveLock(() async {
                      library.repository.saveApplication(saved);
                      if (app.iconPng != saved.iconPng) {
                        await library.entries.refreshIcons(
                          saved,
                          library.repository.profiles
                              .where(
                                (profile) => profile.applicationId == saved.id,
                              )
                              .toList(),
                        );
                      }
                    });
                  }
                }
              }),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'update', child: Text(l.update)),
                PopupMenuItem(value: 'edit', child: Text(l.edit)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(app.executable, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(
          app.portableRoot == null
              ? l.externalApplication
              : l.managedApplication,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            Text(l.profiles, style: Theme.of(context).textTheme.titleLarge),
            OutlinedButton.icon(
              onPressed: busy ? null : () => perform(() => editProfile()),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.newProfile),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.desktopIntegrationHelp),
        const SizedBox(height: 16),
        if (library.profiles.isEmpty)
          Center(child: Text(l.emptyProfiles))
        else
          for (final profile in library.profiles) profileCard(profile, l),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icon/icon.png',
              width: 36,
              height: 36,
              semanticLabel: l.appName,
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(l.appName)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.errors,
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ErrorsScreen(library: library),
                    ),
                  ),
          ),
          IconButton(
            tooltip: l.settings,
            onPressed: busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        preferences: widget.preferences,
                        library: library,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: DesktopContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.library,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(l.isolationNotice),
                  ],
                ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: l.addApplication,
                  onSelected: (kind) => perform(() => add(kind)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'executable',
                      child: Text(l.executable),
                    ),
                    PopupMenuItem(value: 'folder', child: Text(l.folder)),
                    PopupMenuItem(value: 'archive', child: Text(l.archive)),
                  ],
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded),
                          const SizedBox(width: 8),
                          Text(l.addApplication),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (busy) LinearProgressIndicator(semanticsLabel: l.busy),
            Expanded(
              child: ListenableBuilder(
                listenable: library,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    if (library.applications.isEmpty) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_outlined,
                                size: 72,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l.emptyLibrary,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l.emptyLibraryDetail,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (constraints.maxWidth >= 940) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 250, child: applicationList(l)),
                          const SizedBox(width: 32),
                          Expanded(child: profilePanel(l)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(library.selected?.id),
                          initialValue: library.selected?.id,
                          decoration: InputDecoration(labelText: l.library),
                          isExpanded: true,
                          items: [
                            for (final app in library.applications)
                              DropdownMenuItem(
                                value: app.id,
                                child: Text(
                                  app.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: library.select,
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: profilePanel(l)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationNameDialog extends StatefulWidget {
  const _ApplicationNameDialog({required this.initial});
  final String initial;
  @override
  State<_ApplicationNameDialog> createState() => _ApplicationNameDialogState();
}

class _ApplicationNameDialogState extends State<_ApplicationNameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.name),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l.name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
