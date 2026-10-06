import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/live_event_notification_service.dart';
import '../application/create_event_use_case.dart';
import '../application/get_event_use_case.dart';
import '../application/list_events_use_case.dart';
import '../application/update_event_use_case.dart';
import '../domain/event.dart';
import '../domain/events_repository.dart';

class EventsController extends ChangeNotifier {
  final ListEventsUseCase listEvents;
  final GetEventUseCase getEvent;
  final CreateEventUseCase createEvent;
  final UpdateEventUseCase updateEventUseCase;
  final EventsRepository eventsRepository;

  bool _notifyScheduled = false;

  String? _idToken;
  String? _sessionUserId;
  int _sessionEpoch = 0;
  int _selectionEpoch = 0;
  int _listEpoch = 0;
  int _activeLoads = 0;
  bool _loading = false;
  Object? _error;
  Object? _selectedError;

  List<Event> _events = const [];
  Event? _selected;

  EventsController({
    required this.listEvents,
    required this.getEvent,
    required this.createEvent,
    required this.updateEventUseCase,
    required this.eventsRepository,
  });

  bool get loading => _loading;
  Object? get error => _error;
  Object? get selectedError => _selectedError;
  List<Event> get events => _events;
  Event? get selected => _selected;

  void _safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void setIdToken(String? token, {String? userId}) {
    if (_idToken == token && _sessionUserId == userId) return;

    final sameUser = token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty &&
        userId == _sessionUserId;
    _idToken = token;
    _sessionUserId = userId;
    if (sameUser) return;

    _sessionEpoch++;
    _selectionEpoch++;
    _listEpoch++;
    _activeLoads = 0;
    _loading = false;
    _error = null;
    _selectedError = null;
    _events = const [];
    _selected = null;
    _safeNotify();
  }

  Future<void> refresh() async {
    final session = _sessionEpoch;
    final request = ++_listEpoch;
    _activeLoads++;
    _setLoading(true);
    try {
      _error = null;
      final events = await listEvents.execute();
      if (session != _sessionEpoch || request != _listEpoch) return;
      _events = events;
      _updateLiveNotification();
    } catch (e) {
      if (session == _sessionEpoch && request == _listEpoch) _error = e;
    } finally {
      if (session == _sessionEpoch) {
        _activeLoads--;
        _setLoading(_activeLoads > 0);
      }
    }
  }

  void _updateLiveNotification() {
    final notifService = LiveEventNotificationService();
    notifService.checkAndUpdate(_events);
    LiveEventNotificationService.cacheEvents(_events);
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
    final session = _sessionEpoch;
    _activeLoads++;
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

      if (session != _sessionEpoch) return;
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
      if (session == _sessionEpoch) _error = e;
      rethrow;
    } finally {
      if (session == _sessionEpoch) {
        _activeLoads--;
        _setLoading(_activeLoads > 0);
      }
    }
  }

  Future<void> select(String id) async {
    final session = _sessionEpoch;
    final request = ++_selectionEpoch;
    _activeLoads++;
    _setLoading(true);
    try {
      _error = null;
      _selectedError = null;
      final event = await getEvent.execute(id);
      if (session != _sessionEpoch || request != _selectionEpoch) return;
      _selected = event;
    } catch (e) {
      if (session == _sessionEpoch && request == _selectionEpoch) {
        _error = e;
        _selectedError = e;
      }
    } finally {
      if (session == _sessionEpoch) {
        _activeLoads--;
        _setLoading(_activeLoads > 0);
      }
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
    final session = _sessionEpoch;
    _activeLoads++;
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
      if (session == _sessionEpoch) _events = [created, ..._events];
    } catch (e) {
      if (session == _sessionEpoch) _error = e;
      rethrow;
    } finally {
      if (session == _sessionEpoch) {
        _activeLoads--;
        _setLoading(_activeLoads > 0);
      }
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final session = _sessionEpoch;
    try {
      _error = null;
      await eventsRepository.deleteEvent(eventId);
      if (session != _sessionEpoch) return;
      _events = _events.where((e) => e.id != eventId).toList(growable: false);
      if (_selected?.id == eventId) {
        _selected = null;
      }
      _safeNotify();
    } catch (e) {
      if (session == _sessionEpoch) _error = e;
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    _safeNotify();
  }
}
