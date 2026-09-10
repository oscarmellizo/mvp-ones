import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class AccountApiRepository {
  final Dio Function(String? idToken) _dioFactory;

  AccountApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  Future<AccountStatus?> getStatus(String idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/account',
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final status = (data['status']?.toString() ?? 'ACTIVE').toUpperCase();
      final disabledAt = _tryParseDate(data['disabledAt']);
      final reactivatedAt = _tryParseDate(data['reactivatedAt']);
      return AccountStatus(status: status, disabledAt: disabledAt, reactivatedAt: reactivatedAt);
    }
    return null;
  }

  Future<bool> deactivate(String idToken) async {
    final res = await _dioFactory(idToken).post(
      '/v1/account:deactivate',
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );
    return res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
  }

  Future<AccountStatus?> reactivate(String idToken) async {
    try {
      final res = await _dioFactory(idToken).post(
        '/v1/account:reactivate',
        options: Options(
          extra: {
            'secure': [
              {
                'type': 'http',
                'scheme': 'bearer',
                'name': 'bearerAuth',
              }
            ],
          },
        ),
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final status = (data['status']?.toString() ?? 'ACTIVE').toUpperCase();
        final disabledAt = _tryParseDate(data['disabledAt']);
        final reactivatedAt = _tryParseDate(data['reactivatedAt']);
        return AccountStatus(status: status, disabledAt: disabledAt, reactivatedAt: reactivatedAt);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return null;
      rethrow;
    }
  }
}

DateTime? _tryParseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

class AccountStatus {
  final String status; // ACTIVE | DISABLED
  final DateTime? disabledAt;
  final DateTime? reactivatedAt;

  const AccountStatus({required this.status, this.disabledAt, this.reactivatedAt});
}
