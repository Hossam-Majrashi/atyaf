import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/home/services/library_controller.dart';
import '../../features/logs/services/log_service.dart';
import '../../shared/widgets/desktop_content.dart';
import 'diagnostic_reports.dart';
import 'logs_screen.dart';
import 'report_actions.dart';

class ErrorsScreen extends StatelessWidget {
  const ErrorsScreen({super.key, required this.library});
  final LibraryController library;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.errors)),
      body: DesktopContent(
        child: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            final errors = library.repository.errors;
            final failed =
                [
                  for (final profile in library.repository.profiles)
                    for (final record in library.repository.history(profile.id))
                      if (record['crashed'] == true ||
                          record['interrupted'] == true)
                        (profile, record),
                ]..sort(
                  (a, b) => (b.$2['start'] as String? ?? '').compareTo(
                    a.$2['start'] as String? ?? '',
                  ),
                );
            if (errors.isEmpty && failed.isEmpty) {
              return Center(child: Text(l.noErrors));
            }
            return ListView(
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
                        title: Text(error['time'] as String? ?? l.unavailable),
                        subtitle: Text(
                          error['detail'] as String? ?? l.unavailable,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ReportActions(
                                  library: library,
                                  fileName: 'atyaf-error-${error['id']}.txt',
                                  buildReport: () async =>
                                      applicationErrorReport(l, error),
                                ),
                                const SizedBox(height: 16),
                                Text(l.logPreview),
                                for (final section in applicationErrorReport(
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
            );
          },
        ),
      ),
    );
  }
}
