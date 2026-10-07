import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/logs/services/log_service.dart';
import '../../shared/widgets/desktop_content.dart';
import 'diagnostic_reports.dart';
import 'logs_screen.dart';
import 'report_actions.dart';

class ErrorsScreen extends StatefulWidget {
  const ErrorsScreen({super.key, required this.library});
  final LibraryController library;
  @override
  State<ErrorsScreen> createState() => _ErrorsScreenState();
}

class _ErrorsScreenState extends State<ErrorsScreen> {
  bool clearing = false;
  LibraryController get library => widget.library;

  Future<void> clear(
    List<Map<String, dynamic>> errors,
    List<Map<String, dynamic>> failed,
  ) async {
    if (clearing) return;
    final l = AppLocalizations.of(context);
    final errorIds = errors.map((record) => record['id'] as String).toList();
    setState(() => clearing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.clearErrors),
          content: SingleChildScrollView(child: Text(l.clearErrorsConfirm)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.clearErrors),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await library.clearDiagnostics(
        errorIds: errorIds,
        failedLaunches: failed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorsCleared)));
      }
    } catch (error, stack) {
      library.reportError(error, stack);
      library.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.error(error.toString()))));
      }
    } finally {
      if (mounted) setState(() => clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final errors = library.repository.errors;
        final failed = library.failedDiagnostics;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.errors),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l.clearErrors),
                onPressed: clearing || (errors.isEmpty && failed.isEmpty)
                    ? null
                    : () =>
                          clear(errors, failed.map((item) => item.$2).toList()),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: DesktopContent(
            child: errors.isEmpty && failed.isEmpty
                ? Center(child: Text(l.noErrors))
                : ListView(
                    children: [
                      Text(l.reportPrivacy),
                      const SizedBox(height: 16),
                      ReportActions(
                        library: library,
                        buildReport: () async {
                          final sections = <ReportSection>[];
                          for (final error in errors) {
                            sections.addAll(applicationErrorReport(l, error));
                          }
                          for (final item in failed) {
                            sections.addAll(
                              await launchReport(l, library, item.$1, item.$2),
                            );
                          }
                          return sections;
                        },
                      ),
                      if (errors.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          l.applicationErrors,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final error in errors)
                          Card(
                            child: ExpansionTile(
                              key: ValueKey(error['id']),
                              title: Text(
                                error['time'] as String? ?? l.unavailable,
                              ),
                              subtitle: Text(
                                error['detail'] as String? ?? l.unavailable,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ReportActions(
                                        library: library,
                                        fileName:
                                            'atyaf-error-${error['id']}.txt',
                                        buildReport: () async =>
                                            applicationErrorReport(l, error),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(l.logPreview),
                                      for (final section
                                          in applicationErrorReport(
                                            l,
                                            error,
                                          )) ...[
                                        Text(
                                          section.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        SelectableText(
                                          LogService.previewText(section.text),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (failed.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          l.failedLaunches,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final item in failed)
                          LaunchLogCard(
                            key: ValueKey(item.$2['id']),
                            library: library,
                            profile: item.$1,
                            record: item.$2,
                          ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}
