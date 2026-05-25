import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

class TranslationsService {
  final OnesApiClient _apiClient;
  final SharedPreferences _prefs;

  static const String _languageKey = 'ones.language_preference';
  static const String _translationsCacheKey = 'ones.translations_cache_';

  Map<String, Map<String, String>> _translationsCache = {};
  String? _currentLanguage;

  TranslationsService(this._apiClient, this._prefs);

  Future<void> init() async {
    _currentLanguage = _prefs.getString(_languageKey) ?? 'es';
    await _loadTranslations(_currentLanguage!);
  }

  String getCurrentLanguage() => _currentLanguage ?? 'es';

  Future<void> setLanguage(String languageCode) async {
    if (!['es', 'en', 'pt'].contains(languageCode)) {
      throw ArgumentError('Invalid language code. Valid values: es, en, pt');
    }
    _currentLanguage = languageCode;
    await _prefs.setString(_languageKey, languageCode);
    await _loadTranslations(languageCode);
  }

  String translate(String key, {String? fallback}) {
    final lang = _currentLanguage ?? 'es';
    final langTranslations = _translationsCache[lang];

    if (langTranslations != null && langTranslations.containsKey(key)) {
      return langTranslations[key]!;
    }

    // Fallback to Spanish if translation not found in current language
    final esTranslations = _translationsCache['es'];
    if (esTranslations != null && esTranslations.containsKey(key)) {
      return esTranslations[key]!;
    }

    return fallback ?? key;
  }

  Future<void> _loadTranslations(String languageCode) async {
    try {
      // Try to load from cache first
      final cached = _prefs.getString('$_translationsCacheKey$languageCode');
      if (cached != null) {
        _translationsCache[languageCode] =
            Map<String, String>.from(jsonDecode(cached)).cast<String, String>();
        return;
      }

      // Fetch from backend - will need to implement this after API client is regenerated
      // For now, use empty map
      _translationsCache[languageCode] = {};

      // Cache the translations
      await _prefs.setString(
        '$_translationsCacheKey$languageCode',
        jsonEncode(_translationsCache[languageCode]),
      );
    } catch (e) {
      // If loading fails, ensure we have at least an empty map
      _translationsCache[languageCode] = {};
    }
  }

  Future<void> refreshTranslations() async {
    if (_currentLanguage != null) {
      await _loadTranslations(_currentLanguage!);
    }
  }
}
