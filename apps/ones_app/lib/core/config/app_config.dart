import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  final String env;
  final String apiBaseUrl;
  final String? googleWebClientId;

  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.googleWebClientId,
  });

  static const _assetPath = 'assets/config/app_config.json';

  static Future<AppConfig> load() async {
    final fromDefine = AppConfig.fromDartDefines();
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return fromDefine;
      }

      final env = (json['env'] as String?) ?? fromDefine.env;
      final apiBaseUrl =
          (json['apiBaseUrl'] as String?) ?? fromDefine.apiBaseUrl;
      final googleWebClientIdFromFile = json['googleWebClientId'] as String?;
      final googleWebClientId = fromDefine.googleWebClientId ??
          (googleWebClientIdFromFile == null ||
                  googleWebClientIdFromFile.isEmpty
              ? null
              : googleWebClientIdFromFile);

      return AppConfig(
        env: env,
        apiBaseUrl: apiBaseUrl,
        googleWebClientId: googleWebClientId,
      );
    } catch (_) {
      return fromDefine;
    }
  }

  factory AppConfig.fromDartDefines() {
    const env = String.fromEnvironment('ONES_ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment('ONES_API_BASE_URL',
        defaultValue: 'http://localhost:8080');
    const googleWebClientId =
        String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

    return AppConfig(
      env: env,
      apiBaseUrl: apiBaseUrl,
      googleWebClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
    );
  }
}
