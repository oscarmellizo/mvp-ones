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

      // Use default translations
      _translationsCache[languageCode] = _getDefaultTranslations(languageCode);

      // Fetch from backend (only if user is authenticated)
      // If not authenticated, skip backend fetch and use default translations
      // TODO: Integrate with AuthController to get token for authenticated requests
      // For now, skip backend fetch to prevent 401 errors
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
      // If loading fails, use default translations
      _translationsCache[languageCode] = _getDefaultTranslations(languageCode);
    }
  }

  Map<String, String> _getDefaultTranslations(String languageCode) {
    switch (languageCode) {
      case 'es':
        return {
          'profile.no_authenticated_user': 'No hay usuario autenticado.',
          'profile.account': 'Cuenta',
          'profile.first_name': 'Nombre',
          'profile.last_name': 'Apellido',
          'profile.email': 'Correo electrónico',
          'profile.preferences': 'Preferencias',
          'profile.preferred_name_question': '¿Cómo te gusta que te llamen?',
          'profile.preferred_name_hint': 'Nombre preferido',
          'profile.preferred_name_description':
              'Este nombre se usa para indicar cuáles son tus fotos.',
          'profile.language': 'Idioma',
          'profile.language_es': 'Español',
          'profile.language_en': 'English',
          'profile.language_pt': 'Português',
          'profile.save_preferences': 'Guardar preferencias',
          'profile.error_preferred_name_required':
              'El nombre preferido es obligatorio.',
          'profile.success_preferences_saved': 'Preferencias guardadas.',
          'profile.error_save_failed':
              'No se pudieron guardar las preferencias.',
          'profile.admin': 'Admin',
          'profile.open_admin': 'Abrir Admin',
          'profile.logout': 'Cerrar sesión',
          'profile.signing_out': 'Cerrando sesión...',
        };
      case 'en':
        return {
          'profile.no_authenticated_user': 'No authenticated user.',
          'profile.account': 'Account',
          'profile.first_name': 'First name',
          'profile.last_name': 'Last name',
          'profile.email': 'Email',
          'profile.preferences': 'Preferences',
          'profile.preferred_name_question': 'How do you like to be called?',
          'profile.preferred_name_hint': 'Preferred name',
          'profile.preferred_name_description':
              'This name is used to indicate which are your photos.',
          'profile.language': 'Language',
          'profile.language_es': 'Español',
          'profile.language_en': 'English',
          'profile.language_pt': 'Português',
          'profile.save_preferences': 'Save preferences',
          'profile.error_preferred_name_required':
              'Preferred name is required.',
          'profile.success_preferences_saved': 'Preferences saved.',
          'profile.error_save_failed': 'Could not save preferences.',
          'profile.admin': 'Admin',
          'profile.open_admin': 'Open Admin',
          'profile.logout': 'Logout',
          'profile.signing_out': 'Signing out...',
        };
      case 'pt':
        return {
          'profile.no_authenticated_user': 'Nenhum usuário autenticado.',
          'profile.account': 'Conta',
          'profile.first_name': 'Nome',
          'profile.last_name': 'Sobrenome',
          'profile.email': 'E-mail',
          'profile.preferences': 'Preferências',
          'profile.preferred_name_question': 'Como você gosta de ser chamado?',
          'profile.preferred_name_hint': 'Nome preferido',
          'profile.preferred_name_description':
              'Este nome é usado para indicar quais são suas fotos.',
          'profile.language': 'Idioma',
          'profile.language_es': 'Español',
          'profile.language_en': 'English',
          'profile.language_pt': 'Português',
          'profile.save_preferences': 'Salvar preferências',
          'profile.error_preferred_name_required':
              'Nome preferido é obrigatório.',
          'profile.success_preferences_saved': 'Preferências salvas.',
          'profile.error_save_failed':
              'Não foi possível salvar as preferências.',
          'profile.admin': 'Admin',
          'profile.open_admin': 'Abrir Admin',
          'profile.logout': 'Sair',
          'profile.signing_out': 'Saindo...',
        };
      default:
        return {};
    }
  }

  Future<void> refreshTranslations() async {
    if (_currentLanguage != null) {
      await _loadTranslations(_currentLanguage!);
    }
  }
}
