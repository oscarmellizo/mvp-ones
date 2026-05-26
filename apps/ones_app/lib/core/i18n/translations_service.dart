import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

class TranslationsService extends ChangeNotifier {
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
    notifyListeners();
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

      // Fetch from backend (only if user is authenticated)
      // If not authenticated, skip backend fetch and use empty cache
      // TODO: Integrate with AuthController to get token for authenticated requests
      // For now, skip backend fetch to prevent 401 errors
      _translationsCache[languageCode] = {};
      return;

      // The following code is disabled for now because it requires authentication
      /*
      final response = await _apiClient
          .getDefaultApi()
          .listTranslations(languageCode: languageCode, extra: {
        'secure': [
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'}
        ]
      });
      final translationMap = <String, String>{};
      final translations = response.data;
      if (translations != null) {
        for (final translation in translations) {
          translationMap[translation.translationKey] = translation.value ?? '';
        }
      }
      _translationsCache[languageCode] = translationMap;

      // Cache the translations
      await _prefs.setString(
        '$_translationsCacheKey$languageCode',
        jsonEncode(translationMap),
      );
      */
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
