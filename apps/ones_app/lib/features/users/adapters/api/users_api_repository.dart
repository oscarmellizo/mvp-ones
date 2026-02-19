import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/users_repository.dart';

class UsersApiRepository implements UsersRepository {
  final Dio Function(String? idToken) _dioFactory;

  UsersApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  UsersApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  @override
  Future<void> ensureUser(String idToken) async {
    await _dioFactory(idToken).post(
      '/v1/users/ensure',
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
  }

  @override
  Future<String?> getPreferredName(String idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/users/me',
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
      final v = data['preferredName'];
      return v is String ? v : null;
    }
    return null;
  }

  @override
  Future<String?> updatePreferredName(
      String idToken, String preferredName) async {
    final res = await _dioFactory(idToken).put(
      '/v1/users/preferences',
      data: {
        'preferredName': preferredName,
      },
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
      final v = data['preferredName'];
      return v is String ? v : null;
    }
    return null;
  }

  @override
  Future<UserLookup?> lookupUserByEmail(String idToken, String email) async {
    try {
      final res = await _dioFactory(idToken).get(
        '/v1/users/lookup',
        queryParameters: {
          'email': email,
        },
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
        final e = data['email'];
        final pn = data['preferredName'];
        if (e is String && e.isNotEmpty) {
          return UserLookup(
            email: e,
            preferredName: pn is String ? pn : null,
          );
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
