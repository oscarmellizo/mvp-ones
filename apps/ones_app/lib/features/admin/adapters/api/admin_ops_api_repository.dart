import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/admin_ops_repository.dart';

class AdminOpsApiRepository implements AdminOpsRepository {
  final Dio Function(String? idToken) _dioFactory;

  AdminOpsApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  AdminOpsApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  @override
  Future<Map<String, dynamic>> getQueues(String idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/admin/ops/queues',
      options: Options(extra: {
        'secure': [
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'bearerAuth',
          }
        ],
      }),
    );
    final data = res.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getMappings(String idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/admin/ops/mappings',
      options: Options(extra: {
        'secure': [
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'bearerAuth',
          }
        ],
      }),
    );
    final data = res.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  @override
  Future<void> setRealtimeMapping(String idToken, bool enabled) async {
    await _dioFactory(idToken).post(
      '/v1/admin/ops/mappings/realtime/$enabled',
      options: Options(extra: {
        'secure': [
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'bearerAuth',
          }
        ],
      }),
    );
  }
}
