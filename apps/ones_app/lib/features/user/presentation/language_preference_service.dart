import 'package:ones_api_client/ones_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreferenceService {
  final OnesApiClient _apiClient;
  final SharedPreferences _prefs;

  static const String _languageKey = 'ones.language_preference';

  LanguagePreferenceService(this._apiClient, this._prefs);

  Future<String?> getLanguagePreference() async {
    return _prefs.getString(_languageKey);
  }

  Future<void> setLanguagePreference(String languageCode) async {
    if (!['es', 'en', 'pt'].contains(languageCode)) {
      throw ArgumentError('Invalid language code. Valid values: es, en, pt');
    }

    await _prefs.setString(_languageKey, languageCode);

    // Also update on backend
    try {
      // Get current user data first to get preferredName
      final currentUser = await _apiClient.v1UsersMe();

      await _apiClient.v1UsersPreferencesPut(
        body: UpdatePreferencesRequest(
          preferredName: currentUser.preferredName ?? 'Guest',
          languagePreference: languageCode,
        ),
      );
    } catch (e) {
      // If backend update fails, still keep local preference
    }
  }
}
