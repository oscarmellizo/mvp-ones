import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/config/app_config.dart';
import '../../../../core/http/ones_api_factory.dart';
import '../../domain/event.dart';
import '../../domain/event_exceptions.dart';
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
  Future<EventQrInfo> getEventQr(String eventId) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/events/$eventId/qr',
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
      throw StateError('Invalid event QR response');
    }
    return EventQrInfo(
      urlLarge: (data['urlLarge'] as String?) ?? (data['urlLatest'] as String?) ?? '',
      urlSmall: data['urlSmall'] as String?,
      urlLatest: (data['urlLatest'] as String?) ?? (data['urlLarge'] as String? ?? ''),
      hash: data['hash'] as String?,
    );
  }

  @override
  Future<EventQrInfo> ensureEventQr(String eventId) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.post(
      '/v1/events/$eventId/qr',
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
      throw StateError('Invalid ensure event QR response');
    }
    return EventQrInfo(
      urlLarge: (data['urlLarge'] as String?) ?? (data['urlLatest'] as String?) ?? '',
      urlSmall: data['urlSmall'] as String?,
      urlLatest: (data['urlLatest'] as String?) ?? (data['urlLarge'] as String? ?? ''),
      hash: data['hash'] as String?,
    );
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
    print('🔍 listEventGuests: eventId=$eventId, Token available=${_idToken != null && _idToken!.isNotEmpty}');
    if (_idToken == null || _idToken!.isEmpty) {
      print('❌ listEventGuests: No token available, returning empty list');
      return const <EventGuest>[];
    }
    
    try {
      final token = await _ensureFreshToken();
      print('🔍 listEventGuests: Calling API with token=${token != null && token.isNotEmpty}');
      final response = await _defaultApi(token).listEventGuests(id: eventId);
      final BuiltList<api.Guest>? items = response.data;
      final count = items?.length ?? 0;
      print('✅ listEventGuests: API returned $count guests');
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
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        print('❌ listEventGuests 401 body: ${e.response?.data}');
      }
      print('❌ listEventGuests failed for eventId=$eventId: $e');
      // Return empty list instead of throwing to prevent app crashes
      return const <EventGuest>[];
    }
  }

  Future<String?> _ensureFreshToken() async {
    try {
      final fresh = await _apiFactory.refreshToken();
      if (fresh != null && fresh.isNotEmpty) {
        print('🔄 Token refreshed, using fresh token');
        return fresh;
      }
    } catch (e) {
      print('⚠️ Token refresh failed: $e');
    }
    return _idToken;
  }

  @override
  Future<List<EventGuest>> listEventGuestsV2(String eventId) async {
    return _listEventGuestsV2WithRetry(eventId, maxRetries: 2);
  }

  Future<List<EventGuest>> _listEventGuestsV2WithRetry(String eventId, {int maxRetries = 2, int attempt = 0}) async {
    print('🔍 listEventGuestsV2: Attempt ${attempt + 1}/$maxRetries, Token available=${_idToken != null && _idToken!.isNotEmpty}');
    
    if (_idToken == null || _idToken!.isEmpty) {
      print('❌ listEventGuestsV2: No token available, falling back to listEventGuests');
      return listEventGuests(eventId);
    }
    
    try {
      final token = await _ensureFreshToken();
      final response = await _defaultApi(token).listEventGuestsV2(id: eventId);
      final BuiltList<api.GuestV2>? items = response.data;
      final guestCount = items?.length ?? 0;
      print('✅ listEventGuestsV2: Successfully loaded $guestCount guests on attempt ${attempt + 1}');
      return (items?.toList() ?? const <api.GuestV2>[])
          .map(
            (g) => EventGuest(
              userId: g.userId,
              email: g.email,
              displayName: g.displayName,
              role: g.role.name,
              status: g.status.name,
            ),
          )
          .toList(growable: false);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        print('⚠️ listEventGuestsV2 401 body: ${e.response?.data}');
      }
      print('⚠️ listEventGuestsV2 failed on attempt ${attempt + 1}: $e');
      
      // Retry on 401 errors (might be timing issues with token)
      if (attempt < maxRetries && e.toString().contains('401')) {
        print('🔄 listEventGuestsV2: Retrying after 500ms delay...');
        await Future.delayed(const Duration(milliseconds: 500));
        return _listEventGuestsV2WithRetry(eventId, maxRetries: maxRetries, attempt: attempt + 1);
      }
      
      print('⚠️ listEventGuestsV2: Max retries reached, falling back to listEventGuests');
      return listEventGuests(eventId);
    }
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

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _apiFactory.create(idToken: _idToken).dio.delete(
        '/v1/events/$eventId',
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw EventNotFoundException(eventId);
      }
      if (e.response?.statusCode == 403) {
        throw EventForbiddenException(eventId);
      }
      if (e.response?.statusCode == 409) {
        throw EventHasGuestPhotosException(eventId);
      }
      rethrow;
    }
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
