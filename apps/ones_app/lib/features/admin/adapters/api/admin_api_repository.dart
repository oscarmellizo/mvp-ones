import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/admin_repository.dart';

class AdminApiRepository implements AdminRepository {
  final Dio Function(String? idToken) _dioFactory;

  AdminApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  AdminApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  @override
  Future<bool> isAdmin(String idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/admin/me',
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
      final v = data['isAdmin'];
      return v is bool ? v : false;
    }
    return false;
  }
}
