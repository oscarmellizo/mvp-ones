class PhotoUploadItem {
  final int id;
  final String? ownerId;
  final String eventId;
  final String photoId;
  final String localPath;
  final String contentType;
  final String status;
  final String createdAt;
  final String? s3KeyOriginal;
  final String? frameId;
  final String? orientation;
  final String? cameraType;
  final String? originalFilename;
  final String? metadataCreatedAt;
  final String? filenameCreatedAt;
  final String? createdAtSource;
  final int? deviceUtcOffsetMinutes;
  final int attempts;
  final String? lastError;

  const PhotoUploadItem({
    required this.id,
    required this.ownerId,
    required this.eventId,
    required this.photoId,
    required this.localPath,
    required this.contentType,
    required this.status,
    required this.createdAt,
    required this.s3KeyOriginal,
    required this.frameId,
    required this.orientation,
    required this.cameraType,
    this.originalFilename,
    this.metadataCreatedAt,
    this.filenameCreatedAt,
    this.createdAtSource,
    this.deviceUtcOffsetMinutes,
    required this.attempts,
    required this.lastError,
  });
}
