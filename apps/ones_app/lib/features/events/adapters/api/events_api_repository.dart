import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/config/app_config.dart';
import '../../../../core/http/ones_api_factory.dart';
import '../../domain/event.dart';
import '../../domain/events_repository.dart';

class EventsApiRepository implements EventsRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;
  final OnesApiFactory _apiFactory;

  String? _idToken;

  EventsApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi()),
        _apiFactory = apiFactory;

  EventsApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory,
        _apiFactory = OnesApiFactory(
          const AppConfig(
            env: 'test',
            apiBaseUrl: 'http://localhost:0',
            googleWebClientId: '',
            photosWsUrl: null,
          ),
        );

  void setIdToken(String? token) {
    _idToken = token;
  }

  @override
  Future<List<Event>> listEvents() async {
    final response = await _defaultApi(_idToken).listEvents();
    final BuiltList<api.Event>? items = response.data;
    return (items?.toList() ?? const <api.Event>[])
        .map(_mapEventApi)
        .toList(growable: false);
  }

  @override
  Future<Event> getEvent(String id) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/events/$id',
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
    if (data is! Map<String, dynamic>) {
      final ct = res.headers.value('content-type');
      final status = res.statusCode;
      String preview = '';
      if (data is String) {
        preview = data.length > 280 ? data.substring(0, 280) : data;
      } else if (data != null) {
        preview = data.toString();
        preview = preview.length > 280 ? preview.substring(0, 280) : preview;
      }

      throw StateError(
        'Invalid get event response (status=$status content-type=$ct body=$preview)',
      );
    }
    return _mapEventJson(data);
  }

  @override
  Future<EventInviteLink> getInviteLink(String eventId) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/events/$eventId/invite-link',
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
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid invite link response');
    }
    return EventInviteLink(
      url: (data['url'] as String?) ?? '',
      enabled: (data['enabled'] as bool?) ?? true,
    );
  }

  @override
  Future<EventInviteLink> setInviteLinkEnabled(
      String eventId, bool enabled) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.put(
      '/v1/events/$eventId/invite-link',
      data: <String, dynamic>{
        'enabled': enabled,
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
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid set invite link response');
    }
    return EventInviteLink(
      url: (data['url'] as String?) ?? '',
      enabled: (data['enabled'] as bool?) ?? true,
    );
  }

  @override
  Future<EventInviteLinkPreview> previewInviteLink(
      String eventId, String sig) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/events/$eventId/invite-link/preview',
      queryParameters: {
        'sig': sig,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid invite link preview response');
    }
    return EventInviteLinkPreview(
      id: data['id'] as String,
      title: data['title'] as String,
      objective: data['objective'] as String,
      location: data['location'] as String,
      startAt: DateTime.parse(data['startAt'] as String),
      endAt: DateTime.parse(data['endAt'] as String),
      coverKey: data['coverKey'] as String?,
    );
  }

  @override
  Future<void> acceptInviteLink(String eventId, String sig) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    await dio.post(
      '/v1/events/$eventId/invite-link/accept',
      queryParameters: {
        'sig': sig,
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
  }

  @override
  Future<List<EventGuest>> listEventGuests(String eventId) async {
    final response = await _defaultApi(_idToken).listEventGuests(id: eventId);
    final BuiltList<api.Guest>? items = response.data;
    return (items?.toList() ?? const <api.Guest>[])
        .map(
          (g) => EventGuest(
            userId: null,
            email: g.email,
            displayName: g.displayName,
            role: g.role.name,
            status: g.status.name,
          ),
        )
        .toList();
  }

  @override
  Future<List<EventGuest>> listEventGuestsV2(String eventId) async {
    final res = await _apiFactory.create(idToken: _idToken).dio.get(
          '/v1/events/$eventId/guests/v2',
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
    if (data is! List) {
      throw StateError('Invalid guests v2 response');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => EventGuest(
            userId: row['userId'] as String?,
            email: row['email'] as String?,
            displayName: row['displayName'] as String?,
            role: (row['role'] as String?) ?? 'guest',
            status: (row['status'] as String?) ?? 'invited',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<EventGuest>> inviteEventGuests(
      String eventId, List<String> inviteeEmails) async {
    final req = api.InviteEventGuestsRequest(
      (b) => b..inviteeEmails.replace(inviteeEmails),
    );
    final response = await _defaultApi(_idToken)
        .inviteEventGuests(id: eventId, inviteEventGuestsRequest: req);
    final BuiltList<api.Guest>? items = response.data;
    return (items?.toList() ?? const <api.Guest>[])
        .map(
          (g) => EventGuest(
            userId: null,
            email: g.email,
            displayName: g.displayName,
            role: g.role.name,
            status: g.status.name,
          ),
        )
        .toList();
  }

  @override
  Future<Event> createEvent(
    String title,
    String objective,
    String location,
    DateTime startAt,
    DateTime endAt,
    String? coverReservationId,
    List<String> inviteeEmails,
    bool allowGuestInvites,
    List<String> frameIds,
  ) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final payload = <String, dynamic>{
      'title': title,
      'objective': objective,
      'location': location,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'coverReservationId': coverReservationId,
      'inviteeEmails': inviteeEmails,
      'allowGuestInvites': allowGuestInvites,
      'frameIds': frameIds,
    };

    final response = await dio.post(
      '/v1/events',
      data: payload,
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
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid create event response');
    }

    return Event(
      id: data['id'] as String,
      ownerId: data['ownerId'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      title: data['title'] as String,
      objective: data['objective'] as String,
      location: data['location'] as String,
      startAt: DateTime.parse(data['startAt'] as String),
      endAt: DateTime.parse(data['endAt'] as String),
      coverKey: data['coverKey'] as String?,
      allowGuestInvites: (data['allowGuestInvites'] as bool?) ?? true,
      inviteLinkEnabled: (data['inviteLinkEnabled'] as bool?) ?? true,
      frameIds: (data['frameIds'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }

  @override
  Future<Event> updateEvent({
    required String eventId,
    required String title,
    required String objective,
    required String location,
    required DateTime startAt,
    required DateTime endAt,
    required bool allowGuestInvites,
    required List<String> frameIds,
    String? coverReservationId,
  }) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final payload = <String, dynamic>{
      'title': title,
      'objective': objective,
      'location': location,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'coverReservationId': coverReservationId,
      'allowGuestInvites': allowGuestInvites,
      'frameIds': frameIds,
    };

    final response = await dio.put(
      '/v1/events/$eventId',
      data: payload,
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
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid update event response');
    }
    return _mapEventJson(data);
  }

  static Event _mapEventJson(Map<String, dynamic> data) {
    return Event(
      id: data['id'] as String,
      ownerId: data['ownerId'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      title: data['title'] as String,
      objective: data['objective'] as String,
      location: data['location'] as String,
      startAt: DateTime.parse(data['startAt'] as String),
      endAt: DateTime.parse(data['endAt'] as String),
      coverKey: data['coverKey'] as String?,
      allowGuestInvites: (data['allowGuestInvites'] as bool?) ?? true,
      inviteLinkEnabled: (data['inviteLinkEnabled'] as bool?) ?? true,
      frameIds: (data['frameIds'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }

  static Event _mapEventApi(api.Event e) {
    return Event(
      id: e.id,
      ownerId: e.ownerId,
      createdAt: e.createdAt,
      title: e.title,
      objective: e.objective,
      location: e.location,
      startAt: e.startAt,
      endAt: e.endAt,
      coverKey: e.coverKey,
      allowGuestInvites: e.allowGuestInvites ?? true,
      inviteLinkEnabled: true,
      frameIds: const <String>[],
    );
  }
}
