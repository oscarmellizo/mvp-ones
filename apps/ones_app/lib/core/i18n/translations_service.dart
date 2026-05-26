import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../../../features/auth/presentation/auth_controller.dart';

class TranslationsService extends ChangeNotifier {
  final OnesApiClient _apiClient;
  SharedPreferences? _prefs;
  AuthController? _authController;

  static const String _languageKey = 'ones.language_preference';
  static const String _translationsCacheKey = 'ones.translations_cache_';
  static const String _translationsCacheTimestampKey =
      'ones.translations_cache_timestamp_';
  static const Duration _cacheTtl = Duration(hours: 12);

  Map<String, Map<String, String>> _translationsCache = {};
  String? _currentLanguage;
  bool _isInitialized = false;

  TranslationsService(this._apiClient, [this._prefs]);

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    await init();
  }

  Future<void> init() async {
    if (_prefs == null) return;
    _currentLanguage = _prefs!.getString(_languageKey) ?? 'es';
    await _loadTranslations(_currentLanguage!);
    _isInitialized = true;
  }

  String getCurrentLanguage() => _currentLanguage ?? 'es';

  Future<void> setLanguage(String languageCode) async {
    if (!['es', 'en', 'pt'].contains(languageCode)) {
      throw ArgumentError('Invalid language code. Valid values: es, en, pt');
    }
    _currentLanguage = languageCode;
    if (_prefs != null) {
      await _prefs!.setString(_languageKey, languageCode);
    }
    await _loadTranslations(languageCode);
    notifyListeners();
  }

  void setAuthController(AuthController authController) {
    _authController = authController;
    final token = authController.idToken;
    if (token != null && token.isNotEmpty) {
      _apiClient.setBearerAuth('bearerAuth', token);
    }

    // Reload translations when auth controller is set (user may have just logged in)
    if (_currentLanguage != null) {
      _loadTranslations(_currentLanguage!);
    }
  }

  String translate(String key, {String? fallback}) {
    final lang = _currentLanguage ?? 'es';
    final langTranslations = _translationsCache[lang];

    if (langTranslations != null && langTranslations.containsKey(key)) {
      return langTranslations[key]!;
    }

    return fallback ?? key;
  }

  Future<void> _loadTranslations(String languageCode) async {
    if (_prefs == null) {
      _translationsCache[languageCode] = {};
      notifyListeners();
      return;
    }

    try {
      // Check if cache exists and is still valid (within TTL)
      final cached = _prefs!.getString('$_translationsCacheKey$languageCode');
      final cachedTimestamp =
          _prefs!.getInt('$_translationsCacheTimestampKey$languageCode');

      if (cached != null && cachedTimestamp != null) {
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        if (cacheAge < _cacheTtl.inMilliseconds) {
          final decoded = Map<String, String>.from(jsonDecode(cached))
              .cast<String, String>();

          if (decoded.isNotEmpty) {
            _translationsCache[languageCode] = decoded;
            notifyListeners();
            return;
          }

          await _prefs!.remove('$_translationsCacheKey$languageCode');
          await _prefs!.remove('$_translationsCacheTimestampKey$languageCode');
        }
      }

      final token = _authController?.idToken;
      if (token == null || token.isEmpty) {
        return;
      }

      final response = await _apiClient.getDefaultApi().listTranslations(
        languageCode: languageCode,
        extra: {
          'secure': [
            {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'}
          ]
        },
      );
      final translationMap = <String, String>{};
      final translations = response.data;
      if (translations != null) {
        for (final translation in translations) {
          translationMap[translation.translationKey] = translation.value ?? '';
        }
      }

      _translationsCache[languageCode] = translationMap;

      if (translationMap.isNotEmpty) {
        await _prefs!.setString(
          '$_translationsCacheKey$languageCode',
          jsonEncode(translationMap),
        );
        await _prefs!.setInt(
          '$_translationsCacheTimestampKey$languageCode',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      notifyListeners();
    } catch (e) {
      await _prefs!.remove('$_translationsCacheKey$languageCode');
      await _prefs!.remove('$_translationsCacheTimestampKey$languageCode');
      _translationsCache[languageCode] = {};
      notifyListeners();
    }
  }

  Future<void> refreshTranslations() async {
    if (_currentLanguage != null) {
      await _loadTranslations(_currentLanguage!);
    }
  }
}
