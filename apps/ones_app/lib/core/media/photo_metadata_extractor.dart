import 'dart:io' show File;
import 'dart:typed_data';

import 'photo_date_resolution.dart';

class PhotoMetadataExtractor {
  const PhotoMetadataExtractor();

  Future<DateTime> createdAtFromBytes({
    required Uint8List bytes,
    String? filename,
    DateTime? fallbackModifiedTime,
  }) async {
    return (await const PhotoDateResolver().resolveFromBytes(
      bytes: bytes,
      filename: filename,
      fallbackModifiedTime: fallbackModifiedTime,
    ))
        .createdAt;
  }

  Future<DateTime> createdAtFromFile({
    required File file,
    String? filename,
  }) async {
    DateTime? modified;
    try {
      modified = await file.lastModified();
    } catch (_) {
      // Filesystem metadata is only a low-confidence fallback.
    }

    final fileName = filename ?? file.uri.pathSegments.last;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      bytes = Uint8List(0);
    }
    return (await const PhotoDateResolver().resolveFromBytes(
      bytes: bytes,
      filename: fileName,
      fallbackModifiedTime: modified,
    ))
        .createdAt;
  }
}
