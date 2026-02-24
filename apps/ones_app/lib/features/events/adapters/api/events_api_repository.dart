import 'package:built_collection/built_collection.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/event.dart';
import '../../domain/events_repository.dart';

class EventsApiRepository implements EventsRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;

  String? _idToken;

  EventsApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi());

  EventsApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  @override
  Future<List<Event>> listEvents() async {
    final response = await _defaultApi(_idToken).listEvents();
    final BuiltList<api.Event>? items = response.data;
    return (items?.toList() ?? const <api.Event>[]).map(_mapEvent).toList();
  }

  @override
  Future<Event> getEvent(String id) async {
    final response = await _defaultApi(_idToken).getEvent(id: id);
    final api.Event? e = response.data;
    if (e == null) {
      throw StateError('Missing event in response');
    }
    return _mapEvent(e);
  }

  @override
  Future<List<EventGuest>> listEventGuests(String eventId) async {
    final response = await _defaultApi(_idToken).listEventGuests(id: eventId);
    final BuiltList<api.Guest>? items = response.data;
    return (items?.toList() ?? const <api.Guest>[])
        .map(
          (g) => EventGuest(
            email: g.email,
            displayName: g.displayName,
            role: g.role.name,
            status: g.status.name,
          ),
        )
        .toList();
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
  ) async {
    final req = api.CreateEventRequest((b) => b
      ..title = title
      ..objective = objective
      ..location = location
      ..startAt = startAt
      ..endAt = endAt
      ..coverReservationId = coverReservationId
      ..inviteeEmails.replace(inviteeEmails)
      ..allowGuestInvites = allowGuestInvites);
    final response =
        await _defaultApi(_idToken).createEvent(createEventRequest: req);
    final api.Event? e = response.data;
    if (e == null) {
      throw StateError('Missing event in response');
    }
    return _mapEvent(e);
  }

  static Event _mapEvent(api.Event e) {
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
    );
  }
}
