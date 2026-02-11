import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../config/app_config.dart';

class OnesApiFactory {
  final AppConfig config;

  OnesApiFactory(this.config);

  OnesApiClient create({String? idToken}) {
    final client = OnesApiClient(basePathOverride: config.apiBaseUrl);

    if (idToken != null && idToken.isNotEmpty) {
      client.setBearerAuth('bearerAuth', idToken);
    }

    client.dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );

    return client;
  }
}
