import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/home/services/library_controller.dart';
import 'features/settings/services/preferences_service.dart';
import 'platform/linux/linux_integration.dart';
import 'screens/desktop/home_screen.dart';
import 'screens/desktop/onboarding_screen.dart';
import 'screens/desktop/shortcut_launch.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(800, 600));
  await windowManager.setPreventClose(true);
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  final library = await LinuxIntegration.initialize();
  FlutterError.onError = (details) {
    library.reportError(details.exception, details.stack ?? StackTrace.current);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    library.reportError(error, stack);
    debugPrint('$error\n$stack');
    return true;
  };
  String? profileId;
  if (arguments.length == 2 && arguments.first == '--launch-profile') {
    profileId = arguments[1];
    try {
      if (await launchDesktopShortcut(library, profileId)) {
        library.dispose();
        exit(0);
      }
    } catch (error, stack) {
      library.reportError(error, stack);
      // Normal desktop UI exposes failures and any required approval.
    }
  }
  runApp(
    AtyafApp(
      preferences: preferences,
      library: library,
      launchProfileId: profileId,
    ),
  );
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1100, 760), center: true),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

class AtyafApp extends StatefulWidget {
  const AtyafApp({
    super.key,
    required this.preferences,
    required this.library,
    this.launchProfileId,
    this.manageWindow = true,
  });
  final PreferencesService preferences;
  final LibraryController library;
  final String? launchProfileId;
  final bool manageWindow;
  @override
  State<AtyafApp> createState() => _AtyafAppState();
}

class _AtyafAppState extends State<AtyafApp> with WindowListener {
  final navigator = GlobalKey<NavigatorState>();
  bool closing = false;
  @override
  void initState() {
    super.initState();
    if (widget.manageWindow) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (widget.manageWindow) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (closing) {
      return;
    }
    closing = true;
    try {
      final profiles = widget.library.repository.profiles
          .where((p) => widget.library.processes.isRunning(p.id))
          .toList();
      if (profiles.isNotEmpty) {
        final context = navigator.currentContext!;
        final l = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.close),
            content: Text(l.closeConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.stop),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        for (final profile in profiles) {
          await widget.library.processes.stop(profile.id);
        }
        if (profiles.any((p) => widget.library.processes.isRunning(p.id))) {
          return;
        }
      }
      // A terminated PID is not proof that output and exit metadata are saved.
      await widget.library.processes.waitForPendingExits();
      await windowManager.destroy();
    } catch (error, stack) {
      widget.library.reportError(error, stack);
      final context = navigator.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).error(error.toString())),
          ),
        );
      }
    } finally {
      closing = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigator,
      onGenerateTitle: (context) {
        final title = AppLocalizations.of(context).appName;
        if (widget.manageWindow) {
          unawaited(windowManager.setTitle(title));
        }
        return title;
      },
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: widget.preferences.language == null
          ? null
          : Locale(widget.preferences.language!),
      localeResolutionCallback: (locale, supported) => supported.firstWhere(
        (v) => v.languageCode == locale?.languageCode,
        orElse: () => const Locale('en'),
      ),
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: widget.preferences.theme,
      home: widget.preferences.onboardingDone || widget.launchProfileId != null
          ? HomeScreen(
              library: widget.library,
              preferences: widget.preferences,
              launchProfileId: widget.launchProfileId,
            )
          : OnboardingScreen(preferences: widget.preferences),
    ),
  );
}
