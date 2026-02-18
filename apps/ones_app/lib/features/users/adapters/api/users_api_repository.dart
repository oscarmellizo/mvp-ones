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
}
