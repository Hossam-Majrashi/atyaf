import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/models/library_models.dart';
import 'application_icon_image.dart';

/// A bounded, searchable library shared by the sidebar and compact selector.
class ApplicationBrowser extends StatefulWidget {
  const ApplicationBrowser({
    super.key,
    required this.applications,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Application> applications;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<ApplicationBrowser> createState() => _ApplicationBrowserState();
}

class _ApplicationBrowserState extends State<ApplicationBrowser> {
  final search = TextEditingController();
  final scroll = ScrollController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final applications = query.isEmpty
        ? widget.applications
        : widget.applications
              .where((app) => app.name.toLowerCase().contains(query))
              .toList();
    final indices = {
      for (var index = 0; index < applications.length; index++)
        applications[index].id: index,
    };
    return Column(
      children: [
        TextField(
          controller: search,
          decoration: InputDecoration(
            labelText: l.searchApplications,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (value) {
            if (scroll.hasClients) scroll.jumpTo(0);
            setState(() => query = value.trim().toLowerCase());
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: applications.isEmpty
              ? Center(child: Text(l.noMatchingApplications))
              : ListView.builder(
                  controller: scroll,
                  itemCount: applications.length,
                  findChildIndexCallback: (key) =>
                      indices[(key as ValueKey<String>).value],
                  itemBuilder: (context, index) {
                    final app = applications[index];
                    return Padding(
                      key: ValueKey(app.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        selected: widget.selectedId == app.id,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
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
                        onTap: () => widget.onSelected(app.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
