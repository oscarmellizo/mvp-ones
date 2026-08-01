import 'dart:typed_data';
import 'dart:io' show File;
import 'package:exif/exif.dart' as exif;

class PhotoMetadataExtractor {
  const PhotoMetadataExtractor();

  Future<DateTime> createdAtFromBytes({
    required Uint8List bytes,
    String? filename,
    DateTime? fallbackModifiedTime,
  }) async {
    DateTime? result;

    final exifDt = await _readExifDate(bytes);
    if (exifDt != null) {
      result = exifDt.toUtc();
    }

    final fromName = _parseDateFromFilename(filename ?? '');
    if (fromName != null) {
      final n = fromName.toUtc();
      result = (result == null || n.isBefore(result!)) ? n : result;
    }

    if (fallbackModifiedTime != null) {
      final m = fallbackModifiedTime.toUtc();
      result = (result == null || m.isBefore(result!)) ? m : result;
    }

    return result ?? DateTime.now().toUtc();
  }

  Future<DateTime> createdAtFromFile({
    required File file,
    String? filename,
  }) async {
    DateTime? result;
    try {
      final bytes = await file.readAsBytes();
      final fromExif = await _readExifDate(bytes);
      if (fromExif != null) {
        result = fromExif.toUtc();
      }
    } catch (_) {}

    final fromName = _parseDateFromFilename(filename ?? file.uri.pathSegments.last);
    if (fromName != null) {
      final n = fromName.toUtc();
      result = (result == null || n.isBefore(result!)) ? n : result;
    }

    try {
      final m = await file.lastModified();
      final mu = m.toUtc();
      result = (result == null || mu.isBefore(result!)) ? mu : result;
    } catch (_) {}

    return result ?? DateTime.now().toUtc();
  }

  Future<DateTime?> _readExifDate(Uint8List bytes) async {
    try {
      final data = await exif.readExifFromBytes(bytes);
      if (data.isEmpty) return null;
      final candidates = <String>[
        'EXIF DateTimeOriginal',
        'EXIF DateTimeDigitized',
        'Image DateTime',
      ];
      DateTime? earliest;
      for (final key in candidates) {
        final tag = data[key];
        if (tag == null) continue;
        final value = tag.printable.trim();
        final dt = _parseExifDate(value);
        if (dt == null) continue;
        final u = dt.toUtc();
        earliest = (earliest == null || u.isBefore(earliest!)) ? u : earliest;
      }
      return earliest;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseExifDate(String s) {
    // Typical EXIF: YYYY:MM:DD HH:MM:SS
    final parts = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
        .firstMatch(s);
    if (parts != null) {
      final y = int.parse(parts.group(1)!);
      final m = int.parse(parts.group(2)!);
      final d = int.parse(parts.group(3)!);
      final hh = int.parse(parts.group(4)!);
      final mm = int.parse(parts.group(5)!);
      final ss = int.parse(parts.group(6)!);
      // Interpret as local time if no TZ info, then convert to UTC
      final local = DateTime(y, m, d, hh, mm, ss);
      return local.toUtc();
    }
    return null;
  }

  DateTime? _parseDateFromFilename(String name) {
    if (name.isEmpty) return null;

    // WhatsApp Image 2023-11-05 at 14.22.33.jpeg
    final wa = RegExp(
            r'(\d{4})-(\d{2})-(\d{2}).*?(\d{2})[\.:_](\d{2})[\.:_](\d{2})')
        .firstMatch(name);
    if (wa != null) {
      return DateTime(
        int.parse(wa.group(1)!),
        int.parse(wa.group(2)!),
        int.parse(wa.group(3)!),
        int.parse(wa.group(4)!),
        int.parse(wa.group(5)!),
        int.parse(wa.group(6)!),
      );
    }

    // IMG_20231105_142233 or 20231105_142233
    final ymdhms = RegExp(r'(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})')
        .firstMatch(name);
    if (ymdhms != null) {
      return DateTime(
        int.parse(ymdhms.group(1)!),
        int.parse(ymdhms.group(2)!),
        int.parse(ymdhms.group(3)!),
        int.parse(ymdhms.group(4)!),
        int.parse(ymdhms.group(5)!),
        int.parse(ymdhms.group(6)!),
      );
    }

    // 2023-11-05[_/.]14[.:]22[.:]33 or only date 2023-11-05
    final isoLike = RegExp(
            r'(\d{4})[\-\._](\d{2})[\-\._](\d{2})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?')
        .firstMatch(name);
    if (isoLike != null) {
      final y = int.parse(isoLike.group(1)!);
      final m = int.parse(isoLike.group(2)!);
      final d = int.parse(isoLike.group(3)!);
      final hh = int.tryParse(isoLike.group(4) ?? '') ?? 0;
      final mm = int.tryParse(isoLike.group(5) ?? '') ?? 0;
      final ss = int.tryParse(isoLike.group(6) ?? '') ?? 0;
      return DateTime(y, m, d, hh, mm, ss);
    }

    // DD-MM-YYYY with optional time
    final dmy = RegExp(
            r'(\d{2})[\-\._](\d{2})[\-\._](\d{4})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?')
        .firstMatch(name);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final m = int.parse(dmy.group(2)!);
      final y = int.parse(dmy.group(3)!);
      final hh = int.tryParse(dmy.group(4) ?? '') ?? 0;
      final mm = int.tryParse(dmy.group(5) ?? '') ?? 0;
      final ss = int.tryParse(dmy.group(6) ?? '') ?? 0;
      return DateTime(y, m, d, hh, mm, ss);
    }

    return null;
  }
}
