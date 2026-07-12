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
  Future<UserPreferences?> getPreferences(String idToken) async {
    final dio = _dioFactory(idToken);
    late Response<dynamic> res;
    try {
      res = await dio.get(
        '/v1/users/me',
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store',
            'Pragma': 'no-cache',
          },
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
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[UsersApiRepository] getPreferences DioException status=${e.response?.statusCode} type=${e.type}');
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('[UsersApiRepository] getPreferences unexpected error: $e');
      rethrow;
    }

    // ignore: avoid_print
    print('[UsersApiRepository] getPreferences response status=${res.statusCode} url=${res.requestOptions.uri} body=${res.data}');

    if (res.statusCode == 404) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
      );
    }

    final data = res.data;
    if (data is Map<String, dynamic>) {
      final pn = data['preferredName'];
      final lp = data['languagePreference'];
      return UserPreferences(
        preferredName: pn is String ? pn : null,
        languagePreference: lp is String ? lp : null,
      );
    }
    return null;
  }

  @override
  Future<UserPreferences?> updatePreferences(
    String idToken,
    String preferredName,
    String languagePreference,
  ) async {
    final res = await _dioFactory(idToken).put(
      '/v1/users/preferences',
      data: {
        'preferredName': preferredName,
        'languagePreference': languagePreference,
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
      final pn = data['preferredName'];
      final lp = data['languagePreference'];
      return UserPreferences(
        preferredName: pn is String ? pn : null,
        languagePreference: lp is String ? lp : null,
      );
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
