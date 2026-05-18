import 'package:dio/dio.dart';

class OnesAuthApi {
  final Dio dio;

  OnesAuthApi(this.dio);

  Future<SessionResponse> createSession({required String googleIdToken, required String deviceId}) async {
    final resp = await dio.post<Map<String, dynamic>>(
      '/v1/auth/session',
      data: {
        'googleIdToken': googleIdToken,
        'deviceId': deviceId,
      },
    );

    final data = resp.data ?? <String, dynamic>{};
    return SessionResponse.fromJson(data);
  }

  Future<SessionResponse> refresh({required String refreshToken, required String deviceId}) async {
    final resp = await dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {
        'refreshToken': refreshToken,
        'deviceId': deviceId,
      },
    );

    final data = resp.data ?? <String, dynamic>{};
    return SessionResponse.fromJson(data);
  }

  Future<void> logout({required String refreshToken}) async {
    await dio.post<void>(
      '/v1/auth/logout',
      data: {
        'refreshToken': refreshToken,
      },
    );
  }
}

class SessionResponse {
  final String accessToken;
  final String refreshToken;
  final String accessExpiresAt;
  final String refreshExpiresAt;

  SessionResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      accessToken: (json['accessToken'] ?? '').toString(),
      accessExpiresAt: (json['accessExpiresAt'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      refreshExpiresAt: (json['refreshExpiresAt'] ?? '').toString(),
    );
  }
}
