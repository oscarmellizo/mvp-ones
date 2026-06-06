import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../../../features/auth/presentation/auth_controller.dart';

class TranslationsService extends ChangeNotifier {
  final OnesApiClient _apiClient;
  SharedPreferences? _prefs;
  AuthController? _authController;

  static const String _languageKey = 'ones.language_preference';
  static const int _cacheVersion = 2;
  static const String _translationsCacheKey =
      'ones.translations_cache_v${_cacheVersion}_';
  static const String _translationsCacheTimestampKey =
      'ones.translations_cache_timestamp_v${_cacheVersion}_';
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

    // Apply saved language immediately, even if we can't fetch translations yet.
    notifyListeners();

    final token = _authController?.idToken;
    if (token != null && token.isNotEmpty) {
      _apiClient.setBearerAuth('bearerAuth', token);
    }

    await _loadTranslations(
      _currentLanguage!,
      forceNetwork: false,
    );
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
    await _loadTranslations(languageCode, forceNetwork: true);
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
      _loadTranslations(_currentLanguage!, forceNetwork: true);
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

  Future<void> _loadTranslations(
    String languageCode, {
    bool forceNetwork = false,
  }) async {
    if (_prefs == null) {
      _translationsCache[languageCode] = {};
      notifyListeners();
      return;
    }

    final previous = _translationsCache[languageCode];

    try {
      // Check if cache exists and is still valid (within TTL)
      if (!forceNetwork) {
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
            await _prefs!
                .remove('$_translationsCacheTimestampKey$languageCode');
          }
        }
      }

      final token = _authController?.idToken;
      if (token == null || token.isEmpty) {
        if (previous != null) {
          _translationsCache[languageCode] = previous;
          notifyListeners();
        }
        return;
      }

      final res = await _apiClient.dio.get(
        '/v1/translations',
        queryParameters: {'languageCode': languageCode},
        options: Options(
          extra: {
            'secure': [
              {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'}
            ],
          },
        ),
      );

      final translationMap = <String, String>{};
      final data = res.data;
      if (data is List) {
        for (final row in data) {
          if (row is Map) {
            final k = row['translationKey'];
            final v = row['value'];
            if (k is String && k.isNotEmpty) {
              translationMap[k] = (v is String) ? v : '';
            }
          }
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
      if (kDebugMode) {
        debugPrint('TranslationsService: failed to load translations: $e');
      }
      _translationsCache[languageCode] = previous ?? {};
      notifyListeners();
    }
  }

  Future<void> refreshTranslations({bool forceNetwork = false}) async {
    if (_currentLanguage != null) {
      await _loadTranslations(_currentLanguage!, forceNetwork: forceNetwork);
    }
  }
}
