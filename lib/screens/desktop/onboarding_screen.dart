import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../features/onboarding/services/onboarding_state.dart';
import '../../features/settings/services/preferences_service.dart';
import '../../shared/widgets/desktop_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.preferences});
  final PreferencesService preferences;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final progress = OnboardingState();
  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: DesktopContent(
        child: ListenableBuilder(
          listenable: progress,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/icon/icon.png',
                            width: 96,
                            height: 96,
                            semanticLabel: l.appName,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            [l.intro, l.language, l.theme][progress.step],
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          if (progress.step == 0)
                            Text(
                              l.introDetail,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          if (progress.step == 1)
                            LanguageChoice(preferences: widget.preferences),
                          if (progress.step == 2)
                            ThemeChoice(preferences: widget.preferences),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: () async {
                              if (progress.step < 2) {
                                progress.advance();
                              } else {
                                await widget.preferences.completeOnboarding(
                                  l.localeName,
                                );
                              }
                            },
                            child: Text(progress.step == 2 ? l.finish : l.next),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LanguageChoice extends StatelessWidget {
  const LanguageChoice({super.key, required this.preferences});
  final PreferencesService preferences;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue:
          preferences.language ?? Localizations.localeOf(context).languageCode,
      decoration: InputDecoration(labelText: l.language),
      items: [
        DropdownMenuItem(value: 'en', child: Text(l.english)),
        DropdownMenuItem(value: 'ar', child: Text(l.arabic)),
      ],
      onChanged: (value) {
        if (value != null) {
          preferences.setLanguage(value);
        }
      },
    );
  }
}

class ThemeChoice extends StatelessWidget {
  const ThemeChoice({super.key, required this.preferences});
  final PreferencesService preferences;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<ThemeMode>(
      initialValue: preferences.theme,
      decoration: InputDecoration(labelText: l.theme),
      items: [
        DropdownMenuItem(value: ThemeMode.dark, child: Text(l.dark)),
        DropdownMenuItem(value: ThemeMode.light, child: Text(l.light)),
        DropdownMenuItem(value: ThemeMode.system, child: Text(l.system)),
      ],
      onChanged: (value) {
        if (value != null) {
          preferences.setTheme(value);
        }
      },
    );
  }
}
