class EventPhoto {
  final String photoId;
  final String guestId;
  final DateTime? createdAt;
  final DateTime? uploadedAt;
  final String status;
  final String? originalUrl;
  final String? mediumUrl;
  final String? smallUrl;

  const EventPhoto({
    required this.photoId,
    required this.guestId,
    required this.createdAt,
    required this.uploadedAt,
    required this.status,
    required this.originalUrl,
    required this.mediumUrl,
    required this.smallUrl,
  });
}
