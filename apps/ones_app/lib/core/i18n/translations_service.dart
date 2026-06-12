import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../../../features/auth/presentation/auth_controller.dart';

class TranslationsService extends ChangeNotifier {
  final OnesApiClient _apiClient;
  SharedPreferences? _prefs;

  static const String _languageKey = 'ones.language_preference';
  static const int _cacheVersion = 2;
  static const String _translationsCacheKey =
      'ones.translations_cache_v${_cacheVersion}_';
  static const String _translationsCacheTimestampKey =
      'ones.translations_cache_timestamp_v${_cacheVersion}_';
  static const Duration _cacheTtl = Duration(hours: 24);

  Map<String, Map<String, String>> _translationsCache = {};
  String? _currentLanguage;
  bool _isInitialized = false;

  String? _lastSyncedUserLanguage;
  String? _syncLanguageInFlight;

  Future<void>? _initInFlight;

  final Map<String, Future<void>> _inFlightByPageAndLang = {};

  TranslationsService(this._apiClient, [this._prefs]);

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    final existing = _initInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final f = () async {
      _prefs ??= await SharedPreferences.getInstance();
      await init();
      _isInitialized = true;
    }();

    _initInFlight = f;
    try {
      await f;
    } finally {
      _initInFlight = null;
    }
  }

  Future<void> init() async {
    if (_prefs == null) return;
    _currentLanguage = _prefs!.getString(_languageKey) ?? 'es';

    // Apply saved language immediately, even if we can't fetch translations yet.
    notifyListeners();

    await _loadCachedTranslations(_currentLanguage!);
  }

  String getCurrentLanguage() => _currentLanguage ?? 'es';

  void syncLanguageFromUserPreference(String? languageCode) {
    if (languageCode == null || languageCode.trim().isEmpty) return;
    final normalized = languageCode.trim().toLowerCase();
    if (!['es', 'en', 'pt'].contains(normalized)) return;
    if (_lastSyncedUserLanguage == normalized) return;
    _lastSyncedUserLanguage = normalized;

    if (_syncLanguageInFlight == normalized) return;
    _syncLanguageInFlight = normalized;
    unawaited(
      setLanguage(normalized).whenComplete(() {
        if (_syncLanguageInFlight == normalized) {
          _syncLanguageInFlight = null;
        }
      }),
    );
  }

  Future<void> setLanguage(String languageCode) async {
    await ensureInitialized();
    if (!['es', 'en', 'pt'].contains(languageCode)) {
      throw ArgumentError('Invalid language code. Valid values: es, en, pt');
    }
    _currentLanguage = languageCode;
    if (_prefs != null) {
      await _prefs!.setString(_languageKey, languageCode);
    }
    await _loadCachedTranslations(languageCode);
    notifyListeners();
  }

  void setAuthController(AuthController authController) {
    final token = authController.idToken;
    if (token != null && token.isNotEmpty) {
      _apiClient.setBearerAuth('bearerAuth', token);
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

  Future<void> _loadCachedTranslations(String languageCode) async {
    if (_prefs == null) {
      _translationsCache[languageCode] = {};
      notifyListeners();
      return;
    }

    try {
      final cached = _prefs!.getString('$_translationsCacheKey$languageCode');
      final cachedTimestamp =
          _prefs!.getInt('$_translationsCacheTimestampKey$languageCode');

      if (cached != null && cachedTimestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        if (cacheAge < _cacheTtl.inMilliseconds) {
          final decoded =
              Map<String, String>.from(jsonDecode(cached)).cast<String, String>();
          _translationsCache[languageCode] = decoded;
          notifyListeners();
          return;
        }
      }

      await _prefs!.remove('$_translationsCacheKey$languageCode');
      await _prefs!.remove('$_translationsCacheTimestampKey$languageCode');
      _translationsCache[languageCode] = {};
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TranslationsService: failed to load cached translations: $e');
      }
      _translationsCache[languageCode] = _translationsCache[languageCode] ?? {};
      notifyListeners();
    }
  }

  Future<void> ensurePageTranslations({
    required String page,
    required Set<String> requiredKeys,
  }) async {
    await ensureInitialized();

    final lang = _currentLanguage ?? 'es';
    final existing = _translationsCache[lang] ?? const <String, String>{};

    final hasAll = requiredKeys.every((k) => existing.containsKey(k));
    if (hasAll) return;

    final inFlightKey = '$page::$lang';
    final existingFuture = _inFlightByPageAndLang[inFlightKey];
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final f = _loadPageBundle(page: page, languageCode: lang);
    _inFlightByPageAndLang[inFlightKey] = f;
    try {
      await f;
    } finally {
      _inFlightByPageAndLang.remove(inFlightKey);
    }
  }

  Future<void> _loadPageBundle({
    required String page,
    required String languageCode,
  }) async {
    if (_prefs == null) {
      return;
    }

    final previous = _translationsCache[languageCode] ?? <String, String>{};

    try {
      final res = await _apiClient.dio.get(
        '/v1/translations/page',
        queryParameters: {
          'page': page,
          'languageCode': languageCode,
        },
      );

      final data = res.data;
      final incoming = <String, String>{};
      if (data is Map) {
        final translations = data['translations'];
        if (translations is Map) {
          for (final e in translations.entries) {
            final k = e.key;
            final v = e.value;
            if (k is String && k.isNotEmpty) {
              incoming[k] = (v is String) ? v : '';
            }
          }
        }
      }

      final merged = <String, String>{...previous, ...incoming};
      _translationsCache[languageCode] = merged;

      await _prefs!.setString(
        '$_translationsCacheKey$languageCode',
        jsonEncode(merged),
      );
      await _prefs!.setInt(
        '$_translationsCacheTimestampKey$languageCode',
        DateTime.now().millisecondsSinceEpoch,
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TranslationsService: failed to load page bundle: $e');
      }
      _translationsCache[languageCode] = previous;
      notifyListeners();
    }
  }

  Future<void> refreshTranslations({bool forceNetwork = false}) async {
    if (_currentLanguage != null) {
      await _loadCachedTranslations(_currentLanguage!);
    }
  }
}
