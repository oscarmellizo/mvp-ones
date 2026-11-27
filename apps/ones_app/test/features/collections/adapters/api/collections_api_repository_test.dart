import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/collections/adapters/api/collections_api_repository.dart';

void main() {
  test('loads collection members with bounded cursor pagination', () async {
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'https://appdev.ones.events/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'items': [
                  {
                    'memberKey': 'USER#member-1',
                    'userId': 'member-1',
                    'email': 'member@example.com',
                    'status': 'ACCEPTED',
                  },
                ],
                'nextToken': 'member-cursor',
              },
            ),
          );
        },
      ),
    );
    final repository = CollectionsApiRepository.forTesting((_) => dio);

    final page = await repository.membersPage(
      'collection-1',
      limit: 50,
      nextToken: 'previous-cursor',
    );

    expect(request?.path, '/v1/collections/collection-1/members');
    expect(request?.method, 'GET');
    expect(request?.queryParameters['limit'], 50);
    expect(request?.queryParameters['nextToken'], 'previous-cursor');
    expect(page.items.single.userId, 'member-1');
    expect(page.nextToken, 'member-cursor');
  });

  test('loads pending collection invitations from the bell endpoint', () async {
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'https://appdev.ones.events/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'items': [
                  {
                    'collectionId': 'collection-1',
                    'collectionName': 'Familia',
                    'invitedByUserId': 'owner-1',
                    'createdAt': '2026-11-28T10:00:00Z',
                  },
                ],
                'nextToken': 'cursor-1',
              },
            ),
          );
        },
      ),
    );
    final repository = CollectionsApiRepository.forTesting((token) {
      expect(token, 'test-id-token');
      return dio;
    })
      ..setIdToken('test-id-token');

    final page = await repository.pendingInvitations(limit: 100);

    expect(request?.path, '/v1/collections/invitations');
    expect(request?.method, 'GET');
    expect(request?.queryParameters['limit'], 100);
    expect(request?.extra['secure'], isNotEmpty);
    expect(page.items.single.collectionId, 'collection-1');
    expect(page.items.single.collectionName, 'Familia');
    expect(page.nextToken, 'cursor-1');
  });
}
