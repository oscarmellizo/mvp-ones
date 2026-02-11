class Event {
  final String id;
  final String ownerId;
  final DateTime createdAt;
  final String title;

  const Event({
    required this.id,
    required this.ownerId,
    required this.createdAt,
    required this.title,
  });
}
