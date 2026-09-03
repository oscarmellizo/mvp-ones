import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ones_app/features/admin/adapters/api/admin_ops_api_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  test('AdminOpsApiRepository.getQueues returns map', () async {
    final dio = _MockDio();
    when(() => dio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {'ok': true},
          requestOptions: RequestOptions(path: '/v1/admin/ops/queues'),
          statusCode: 200,
        ));

    final repo = AdminOpsApiRepository.forTesting((_) => dio);
    final res = await repo.getQueues('token');
    expect(res['ok'], true);
  });

  test('AdminOpsApiRepository.getMappings returns map', () async {
    final dio = _MockDio();
    when(() => dio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {'mappings': []},
          requestOptions: RequestOptions(path: '/v1/admin/ops/mappings'),
          statusCode: 200,
        ));

    final repo = AdminOpsApiRepository.forTesting((_) => dio);
    final res = await repo.getMappings('token');
    expect(res['mappings'], isA<List>());
  });
}
