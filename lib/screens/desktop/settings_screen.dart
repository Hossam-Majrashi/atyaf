import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/developer_info.dart';
import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/settings/services/preferences_service.dart';
import '../../shared/widgets/desktop_content.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.library,
  });
  final PreferencesService preferences;
  final LibraryController library;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  Future<void> _launchUrl(String value) async {
    try {
      if (await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (error, stack) {
      widget.library.reportError(error, stack);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openFailed)),
      );
    }
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      onTap: onTap,
    ),
  );
  Future<void> transfer(bool restore) async {
    final l = AppLocalizations.of(context);
    setState(() => busy = true);
    try {
      if (restore) {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: l.importBackup,
          type: FileType.custom,
          allowedExtensions: ['gz'],
        );
        final path = result?.files.single.path;
        if (path == null || !mounted) {
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.importBackup),
            content: Text(l.restoreConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.importBackup),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        final oldIds = widget.library.repository.profiles
            .map((v) => v.id)
            .toList();
        await widget.library.backup.restore(path);
        for (final id in oldIds) {
          await widget.library.entries.remove(id);
        }
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: l.exportBackup,
          fileName: 'atyaf-backup.tar.gz',
        );
        if (path == null) {
          return;
        }
        await widget.library.backup.export(
          path.endsWith('.tar.gz') ? path : '$path.tar.gz',
        );
      }
      widget.library.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.done)));
      }
    } catch (error, stack) {
      widget.library.reportError(error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.error(error.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: DesktopContent(
        child: ListView(
          children: [
            LanguageChoice(preferences: widget.preferences),
            const SizedBox(height: 24),
            ThemeChoice(preferences: widget.preferences),
            const SizedBox(height: 32),
            Text(l.backup, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(l.backupHelp),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => transfer(false),
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(l.exportBackup),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => transfer(true),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l.importBackup),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(semanticsLabel: l.busy),
            ],
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 24),
            Text(l.developer, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text(
              DeveloperInfo.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              context,
              icon: Icons.alternate_email_rounded,
              label: l.email,
              value: DeveloperInfo.email,
              onTap: () => _launchUrl('mailto:${DeveloperInfo.email}'),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              context,
              icon: Icons.public_rounded,
              label: l.website,
              value: DeveloperInfo.websiteDisplay,
              onTap: () => _launchUrl(DeveloperInfo.websiteUrl),
            ),
          ],
        ),
      ),
    );
  }
}
