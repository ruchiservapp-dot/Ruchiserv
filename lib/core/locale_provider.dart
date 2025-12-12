import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Locale? get locale => _locale;

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale loc) async {
    if (!['en', 'ml', 'ta', 'kn', 'hi', 'te'].contains(loc.languageCode)) return;

    _locale = loc;
    
    // Sync with LanguageService
    final langService = LanguageService();
    langService.setLanguage(loc.languageCode);
    await langService.loadTranslations(loc.languageCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', loc.languageCode);
    notifyListeners();
  }

  void clearLocale() async {
    _locale = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_code');
    notifyListeners();
  }
}
