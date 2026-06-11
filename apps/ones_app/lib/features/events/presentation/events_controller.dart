import 'package:flutter/foundation.dart';

import '../application/create_event_use_case.dart';
import '../application/get_event_use_case.dart';
import '../application/list_events_use_case.dart';
import '../application/update_event_use_case.dart';
import '../domain/event.dart';

class EventsController extends ChangeNotifier {
  final ListEventsUseCase listEvents;
  final GetEventUseCase getEvent;
  final CreateEventUseCase createEvent;
  final UpdateEventUseCase updateEventUseCase;

  String? _idToken;
  bool _loading = false;
  Object? _error;

  List<Event> _events = const [];
  Event? _selected;

  EventsController({
    required this.listEvents,
    required this.getEvent,
    required this.createEvent,
    required this.updateEventUseCase,
  });

  bool get loading => _loading;
  Object? get error => _error;
  List<Event> get events => _events;
  Event? get selected => _selected;

  void setIdToken(String? token) {
    if (_idToken == token) {
      return;
    }
    _idToken = token;

    _loading = false;
    _error = null;
    _events = const [];
    _selected = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    _setLoading(true);
    try {
      _error = null;
      _events = await listEvents.execute();
    } catch (e) {
      _error = e;
      _events = const [];
      _selected = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEvent({
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
    _setLoading(true);
    try {
      _error = null;
      final updated = await updateEventUseCase.execute(
        eventId: eventId,
        title: title,
        objective: objective,
        location: location,
        startAt: startAt,
        endAt: endAt,
        allowGuestInvites: allowGuestInvites,
        frameIds: frameIds,
        coverReservationId: coverReservationId,
      );

      final list = [..._events];
      final idx = list.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        list[idx] = updated;
        _events = list;
      }
      if (_selected?.id == updated.id) {
        _selected = updated;
      }
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> select(String id) async {
    _setLoading(true);
    try {
      _error = null;
      _selected = await getEvent.execute(id);
    } catch (e) {
      _error = e;
      _selected = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createNew(
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
    _setLoading(true);
    try {
      _error = null;
      final created = await createEvent.execute(
        title,
        objective,
        location,
        startAt,
        endAt,
        coverReservationId,
        inviteeEmails,
        allowGuestInvites,
        frameIds,
      );
      _events = [created, ..._events];
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
