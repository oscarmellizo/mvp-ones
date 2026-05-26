import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../../../features/auth/presentation/auth_controller.dart';

class TranslationsService extends ChangeNotifier {
  final OnesApiClient _apiClient;
  final SharedPreferences _prefs;
  AuthController? _authController;

  static const String _languageKey = 'ones.language_preference';
  static const String _translationsCacheKey = 'ones.translations_cache_';
  static const String _translationsCacheTimestampKey =
      'ones.translations_cache_timestamp_';
  static const Duration _cacheTtl = Duration(hours: 12);

  Map<String, Map<String, String>> _translationsCache = {};
  String? _currentLanguage;

  TranslationsService(this._apiClient, this._prefs);

  void setAuthController(AuthController authController) {
    _authController = authController;
    // Reload translations when auth controller is set (user may have just logged in)
    if (_currentLanguage != null) {
      _loadTranslations(_currentLanguage!);
    }
  }

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
      // Check if cache exists and is still valid (within TTL)
      final cached = _prefs.getString('$_translationsCacheKey$languageCode');
      final cachedTimestamp =
          _prefs.getInt('$_translationsCacheTimestampKey$languageCode');

      if (cached != null && cachedTimestamp != null) {
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        if (cacheAge < _cacheTtl.inMilliseconds) {
          _translationsCache[languageCode] =
              Map<String, String>.from(jsonDecode(cached))
                  .cast<String, String>();
          return;
        }
      }

      // Fetch from backend only if user is authenticated
      final token = _authController?.idToken;
      if (token == null) {
        // User not authenticated, use empty cache
        _translationsCache[languageCode] = {};
        return;
      }

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

      // Cache the translations with timestamp
      await _prefs.setString(
        '$_translationsCacheKey$languageCode',
        jsonEncode(translationMap),
      );
      await _prefs.setInt(
        '$_translationsCacheTimestampKey$languageCode',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // If loading fails, use empty map
      _translationsCache[languageCode] = {};
    }
  }

  Future<void> refreshTranslations() async {
    if (_currentLanguage != null) {
      await _loadTranslations(_currentLanguage!);
    }
  }
}
