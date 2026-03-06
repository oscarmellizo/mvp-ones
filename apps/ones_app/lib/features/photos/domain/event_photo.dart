class EventPhoto {
  final String photoId;
  final String guestId;
  final DateTime? createdAt;
  final DateTime? uploadedAt;
  final String status;
  final String? originalUrl;
  final String? mediumUrl;
  final String? smallUrl;
  final bool shared;
  final String? ownerName;
  final String? sharedByUserId;
  final String? sharedByName;

  const EventPhoto({
    required this.photoId,
    required this.guestId,
    required this.createdAt,
    required this.uploadedAt,
    required this.status,
    required this.originalUrl,
    required this.mediumUrl,
    required this.smallUrl,
    required this.shared,
    required this.ownerName,
    required this.sharedByUserId,
    required this.sharedByName,
  });
}
