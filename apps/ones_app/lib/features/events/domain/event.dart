class Event {
  final String id;
  final String ownerId;
  final DateTime createdAt;
  final String title;
  final String eventTypeId;
  final String location;
  final DateTime startAt;
  final DateTime endAt;

  const Event({
    required this.id,
    required this.ownerId,
    required this.createdAt,
    required this.title,
    required this.eventTypeId,
    required this.location,
    required this.startAt,
    required this.endAt,
  });
}
