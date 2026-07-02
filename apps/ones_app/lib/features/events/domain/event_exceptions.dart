class EventNotFoundException implements Exception {
  final String eventId;
  const EventNotFoundException(this.eventId);
  @override
  String toString() => 'EventNotFoundException: eventId=$eventId';
}

class EventForbiddenException implements Exception {
  final String eventId;
  const EventForbiddenException(this.eventId);
  @override
  String toString() => 'EventForbiddenException: eventId=$eventId';
}

class EventHasGuestPhotosException implements Exception {
  final String eventId;
  const EventHasGuestPhotosException(this.eventId);
  @override
  String toString() => 'EventHasGuestPhotosException: eventId=$eventId';
}
