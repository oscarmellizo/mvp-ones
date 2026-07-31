import 'package:shared_preferences/shared_preferences.dart';
import '../domain/tutorial_version.dart';
import '../domain/tutorial_config.dart';

class TutorialStore {
  static const _seenKey = 'ones.tutorial_seen';
  static const _versionKey = 'ones.tutorial_version';

  TutorialStore();

  String _suffix(String? routeName) => routeName == null || routeName.isEmpty
      ? ''
      : '.$routeName';

  Future<bool> shouldShow({
    String? routeName,
    bool firstLaunch = false,
    bool? remoteSeen,
    int? remoteVersion,
  }) async {
    if (!TutorialConfig.kTutorialEnabled) return false;
    // El autodisparo global (sin ruta) sólo en primer arranque si está habilitado
    if (routeName == null && firstLaunch && !TutorialConfig.showOnFirstLaunch) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final suffix = _suffix(routeName);
    final localSeen = prefs.getBool('$_seenKey$suffix');
    final localVersion = prefs.getInt('$_versionKey$suffix');

    final seen = remoteSeen ?? localSeen ?? false;
    final version = remoteVersion ?? localVersion;

    return !seen || (version == null || version < kTutorialVersion);
  }

  Future<void> markSeen({String? routeName}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = _suffix(routeName);
    await prefs.setBool('$_seenKey$suffix', true);
    await prefs.setInt('$_versionKey$suffix', kTutorialVersion);
  }
}
