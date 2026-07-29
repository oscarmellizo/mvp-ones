import 'package:shared_preferences/shared_preferences.dart';
import '../domain/tutorial_version.dart';
import '../domain/tutorial_config.dart';

class TutorialStore {
  static const _seenKey = 'ones.tutorial_seen';
  static const _versionKey = 'ones.tutorial_version';

  TutorialStore();

  Future<bool> shouldShow({bool firstLaunch = false, bool? remoteSeen, int? remoteVersion}) async {
    if (!TutorialConfig.kTutorialEnabled) return false;
    if (firstLaunch && !TutorialConfig.showOnFirstLaunch) return false;

    final prefs = await SharedPreferences.getInstance();
    final localSeen = prefs.getBool(_seenKey);
    final localVersion = prefs.getInt(_versionKey);

    final seen = remoteSeen ?? localSeen ?? false;
    final version = remoteVersion ?? localVersion;

    return !seen || (version == null || version < kTutorialVersion);
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    await prefs.setInt(_versionKey, kTutorialVersion);
  }
}
