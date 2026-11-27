class CollectionInvitation {
  final String collectionId;
  final String collectionName;
  final String? invitedByUserId;
  final DateTime createdAt;
  final String invitationVersion;

  const CollectionInvitation({
    required this.collectionId,
    required this.collectionName,
    required this.createdAt,
    this.invitedByUserId,
    this.invitationVersion = '',
  });

  String get seenId => 'collection:$collectionId:$invitationVersion';

  factory CollectionInvitation.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt'] as String?;
    return CollectionInvitation(
      collectionId: json['collectionId'] as String? ?? '',
      collectionName: json['collectionName'] as String? ?? '',
      invitedByUserId: json['invitedByUserId'] as String?,
      createdAt: DateTime.tryParse(createdAtValue ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      invitationVersion: createdAtValue ?? '',
    );
  }
}

class CollectionInvitationsPage {
  final List<CollectionInvitation> items;
  final String? nextToken;

  const CollectionInvitationsPage({
    required this.items,
    this.nextToken,
  });
}
