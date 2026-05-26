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

    // TODO: Update backend when user preferences endpoints are available
    // try {
    //   final currentUser = await _apiClient.getDefaultApi().v1UsersMe();
    //   await _apiClient.getDefaultApi().v1UsersPreferencesPut(
    //     body: UpdatePreferencesRequest(
    //       preferredName: currentUser.preferredName ?? 'Guest',
    //       languagePreference: languageCode,
    //     ),
    //   );
    // } catch (e) {
    //   print('Failed to update language preference on backend: $e');
    // }
  }
}
