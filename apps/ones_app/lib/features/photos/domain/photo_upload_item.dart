class PhotoUploadItem {
  final int id;
  final String eventId;
  final String photoId;
  final String localPath;
  final String contentType;
  final String status;
  final String createdAt;
  final String? s3KeyOriginal;
  final int attempts;
  final String? lastError;

  const PhotoUploadItem({
    required this.id,
    required this.eventId,
    required this.photoId,
    required this.localPath,
    required this.contentType,
    required this.status,
    required this.createdAt,
    required this.s3KeyOriginal,
    required this.attempts,
    required this.lastError,
  });
}
