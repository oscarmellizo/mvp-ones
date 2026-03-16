import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const _defaultApiBaseUrl = 'http://localhost:8080';

  static Future<AppConfig> load() async {
    final fromDefine = AppConfig.fromDartDefines();
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return fromDefine;
      }

      final envFromFile = json['env'] as String?;
      final apiBaseUrlFromFile = json['apiBaseUrl'] as String?;
      final googleWebClientIdFromFile = json['googleWebClientId'] as String?;

      final resolvedEnv = fromDefine.env.isNotEmpty
          ? fromDefine.env
          : (envFromFile == null || envFromFile.isEmpty)
              ? 'dev'
              : envFromFile;

      final resolvedApiBaseUrl = (fromDefine.apiBaseUrl != _defaultApiBaseUrl &&
              fromDefine.apiBaseUrl.isNotEmpty)
          ? fromDefine.apiBaseUrl
          : (apiBaseUrlFromFile == null || apiBaseUrlFromFile.isEmpty)
              ? fromDefine.apiBaseUrl
              : apiBaseUrlFromFile;

      final resolvedGoogleWebClientId = fromDefine.googleWebClientId ??
          (googleWebClientIdFromFile == null ||
                  googleWebClientIdFromFile.isEmpty
              ? null
              : googleWebClientIdFromFile);

      if (kIsWeb) {
        return AppConfig(
          env: resolvedEnv,
          apiBaseUrl: resolvedApiBaseUrl,
          googleWebClientId: resolvedGoogleWebClientId,
        );
      }

      return AppConfig(
        env: envFromFile ?? resolvedEnv,
        apiBaseUrl: apiBaseUrlFromFile ?? resolvedApiBaseUrl,
        googleWebClientId: resolvedGoogleWebClientId,
      );
    } catch (_) {
      return fromDefine;
    }
  }

  factory AppConfig.fromDartDefines() {
    const env = String.fromEnvironment('ONES_ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment('ONES_API_BASE_URL',
        defaultValue: _defaultApiBaseUrl);
    const googleWebClientId =
        String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

    return AppConfig(
      env: env,
      apiBaseUrl: apiBaseUrl,
      googleWebClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
    );
  }
}
