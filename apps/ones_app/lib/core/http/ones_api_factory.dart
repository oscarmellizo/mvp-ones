import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../config/app_config.dart';

class OnesApiFactory {
  final AppConfig config;

  Future<String?> Function()? _tokenRefresher;

  OnesApiFactory(this.config);

  void setTokenRefresher(Future<String?> Function()? refresher) {
    _tokenRefresher = refresher;
  }

  OnesApiClient create({String? idToken}) {
    final client = OnesApiClient(basePathOverride: config.apiBaseUrl);

    client.dio.options = client.dio.options.copyWith(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    );

    if (idToken != null && idToken.isNotEmpty) {
      client.setBearerAuth('bearerAuth', idToken);
    }

    client.dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (e.response?.statusCode != 401) {
            handler.next(e);
            return;
          }

          final opts = e.requestOptions;
          final alreadyRetried = opts.extra['__retried_401'] == true;
          if (alreadyRetried) {
            handler.next(e);
            return;
          }

          final refresher = _tokenRefresher;
          if (refresher == null) {
            handler.next(e);
            return;
          }

          final refreshed = await refresher();
          if (refreshed == null || refreshed.isEmpty) {
            handler.next(e);
            return;
          }

          try {
            client.setBearerAuth('bearerAuth', refreshed);

            final mergedHeaders = Map<String, dynamic>.from(opts.headers);
            mergedHeaders['Authorization'] = 'Bearer $refreshed';

            final newOptions = opts.copyWith(
              extra: {...opts.extra, '__retried_401': true},
              headers: mergedHeaders,
            );
            final response = await client.dio.fetch<dynamic>(newOptions);
            handler.resolve(response);
          } catch (err) {
            if (err is DioException) {
              handler.next(err);
              return;
            }
            handler.next(
              DioException(
                requestOptions: opts,
                error: err,
                type: DioExceptionType.unknown,
              ),
            );
          }
        },
      ),
    );

    return client;
  }
}
