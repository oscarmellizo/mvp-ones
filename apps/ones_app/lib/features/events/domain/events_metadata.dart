class EventsMetadata {
  final List<EventCategory> categories;

  const EventsMetadata({required this.categories});

  factory EventsMetadata.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final list = rawCategories is List ? rawCategories : const [];
    return EventsMetadata(
      categories: list
          .whereType<Map>()
          .map((m) => EventCategory.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class EventCategory {
  final String id;
  final String label;
  final List<EventType> eventTypes;

  const EventCategory({
    required this.id,
    required this.label,
    required this.eventTypes,
  });

  factory EventCategory.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['eventTypes'];
    final list = rawTypes is List ? rawTypes : const [];
    return EventCategory(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      eventTypes: list
          .whereType<Map>()
          .map((m) => EventType.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class EventType {
  final String id;
  final String label;

  const EventType({required this.id, required this.label});

  factory EventType.fromJson(Map<String, dynamic> json) {
    return EventType(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
    );
  }
}
