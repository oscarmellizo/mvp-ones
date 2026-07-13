import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart';

import '../config/app_config.dart';

class OnesApiFactory {
  final AppConfig config;

  Future<String?> Function()? _tokenRefresher;

  Future<String?>? _refreshInFlight;

  OnesApiFactory(this.config);

  void setTokenRefresher(Future<String?> Function()? refresher) {
    _tokenRefresher = refresher;
  }

  Future<String?> refreshToken() async {
    final refresher = _tokenRefresher;
    if (refresher == null) return null;

    _refreshInFlight ??= Future<String?>.sync(refresher).whenComplete(() {
      _refreshInFlight = null;
    });

    return _refreshInFlight;
  }

  OnesApiClient create({String? idToken}) {
    final rawBase = config.apiBaseUrl.trim();
    final resolvedBase =
        (rawBase.startsWith('http://') || rawBase.startsWith('https://'))
            ? '${rawBase.replaceFirst(RegExp(r"/+\$"), '')}/api'
            : rawBase;

    final client = OnesApiClient(basePathOverride: resolvedBase);

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

          final secure = opts.extra['secure'];
          final isBearerSecure = secure is List && secure.any(
                (s) => s is Map &&
                    s['type'] == 'http' &&
                    (s['scheme']?.toString().toLowerCase() == 'bearer'),
              );
          final authHeader = (opts.headers['Authorization'] ?? '').toString();
          final hasBearerHeader = authHeader.toLowerCase().startsWith('bearer ');

          if (!isBearerSecure && !hasBearerHeader) {
            handler.next(e);
            return;
          }

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

          _refreshInFlight ??= Future<String?>.sync(refresher).whenComplete(() {
            _refreshInFlight = null;
          });

          final refreshed = await _refreshInFlight;
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
            final statusCode = response.statusCode ?? 0;
            if (statusCode >= 400) {
              handler.next(
                DioException(
                  requestOptions: newOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                ),
              );
            } else {
              handler.resolve(response);
            }
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
