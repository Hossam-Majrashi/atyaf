import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  PreferencesService(this.preferences);
  final SharedPreferences preferences;
  String? get language => preferences.getString('language');
  ThemeMode get theme => ThemeMode.values.firstWhere(
    (v) => v.name == preferences.getString('theme'),
    orElse: () => ThemeMode.system,
  );
  bool get onboardingDone => preferences.getBool('onboarding_done') ?? false;
  Future<void> setLanguage(String value) async {
    await preferences.setString('language', value);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    await preferences.setString('theme', value.name);
    notifyListeners();
  }

  Future<void> completeOnboarding(String defaultLanguage) async {
    await preferences.setString('language', language ?? defaultLanguage);
    await preferences.setString('theme', theme.name);
    await preferences.setBool('onboarding_done', true);
    notifyListeners();
  }
}
