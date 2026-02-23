class Event {
  final String id;
  final String ownerId;
  final DateTime createdAt;
  final String title;
  final String objective;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String? coverKey;

  const Event({
    required this.id,
    required this.ownerId,
    required this.createdAt,
    required this.title,
    required this.objective,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.coverKey,
  });
}
