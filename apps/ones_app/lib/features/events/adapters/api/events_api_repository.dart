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
          ),
        );

  void setIdToken(String? token) {
    _idToken = token;
  }

  @override
  Future<List<Event>> listEvents() async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get('/v1/events');
    final data = res.data;
    if (data is! List) {
      throw StateError('Invalid list events response');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapEventJson)
        .toList(growable: false);
  }

  @override
  Future<Event> getEvent(String id) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get('/v1/events/$id');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid get event response');
    }
    return _mapEventJson(data);
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

    final response = await dio.post('/v1/events', data: payload);
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
      frameIds: (data['frameIds'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
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
      frameIds: (data['frameIds'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}
