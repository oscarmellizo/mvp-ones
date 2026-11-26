enum CollectionType {
  private,
  couple,
  family,
  friends,
  projects,
  other;

  String get apiValue => name.toUpperCase();

  static CollectionType fromApi(Object? value) {
    final normalized = value?.toString().toLowerCase();
    return CollectionType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => CollectionType.other,
    );
  }

  String label(String language) {
    final spanish = language.toLowerCase().startsWith('es');
    return switch (this) {
      CollectionType.private => spanish ? 'Privada' : 'Private',
      CollectionType.couple => spanish ? 'Pareja' : 'Couple',
      CollectionType.family => spanish ? 'Familia' : 'Family',
      CollectionType.friends => spanish ? 'Amigos' : 'Friends',
      CollectionType.projects => spanish ? 'Proyectos' : 'Projects',
      CollectionType.other => spanish ? 'Otro' : 'Other',
    };
  }

  String get iconName => switch (this) {
        CollectionType.private => 'lock',
        CollectionType.couple => 'favorite',
        CollectionType.family => 'family',
        CollectionType.friends => 'group',
        CollectionType.projects => 'work',
        CollectionType.other => 'collections',
      };
}

class OnesCollection {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final CollectionType type;
  final String? coverKey;
  final String? purpose;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool joinEnabled;

  const OnesCollection({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.type,
    required this.coverKey,
    required this.purpose,
    required this.createdAt,
    required this.updatedAt,
    required this.joinEnabled,
  });

  bool get isLifeCollection => purpose == 'LIFE';

  factory OnesCollection.fromJson(Map<String, dynamic> json) {
    return OnesCollection(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: CollectionType.fromApi(json['type']),
      coverKey: json['coverKey'] as String?,
      purpose: json['purpose'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      joinEnabled: json['joinEnabled'] == true,
    );
  }
}

class CollectionMember {
  final String memberKey;
  final String? userId;
  final String? email;
  final String status;
  final String? invitedByUserId;

  const CollectionMember({
    required this.memberKey,
    required this.userId,
    required this.email,
    required this.status,
    required this.invitedByUserId,
  });

  factory CollectionMember.fromJson(Map<String, dynamic> json) =>
      CollectionMember(
        memberKey: json['memberKey'] as String? ?? '',
        userId: json['userId'] as String?,
        email: json['email'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        invitedByUserId: json['invitedByUserId'] as String?,
      );
}
