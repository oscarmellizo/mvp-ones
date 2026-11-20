import 'dart:typed_data';

import 'package:exif/exif.dart' as exif;

class PhotoDateResolution {
  final DateTime createdAt;
  final DateTime? metadataDate;
  final DateTime? filenameDate;
  final String source;
  final bool needsAiFilenameResolution;
  final int deviceUtcOffsetMinutes;

  const PhotoDateResolution({
    required this.createdAt,
    required this.metadataDate,
    required this.filenameDate,
    required this.source,
    required this.needsAiFilenameResolution,
    required this.deviceUtcOffsetMinutes,
  });
}

class PhotoDateResolver {
  const PhotoDateResolver();

  Future<PhotoDateResolution> resolveFromBytes({
    required Uint8List bytes,
    String? filename,
    DateTime? fallbackModifiedTime,
  }) async {
    final metadataDates = await _readExifDates(bytes);
    return _resolve(
      metadataDates: metadataDates,
      filename: filename,
      fallbackModifiedTime: fallbackModifiedTime,
    );
  }

  static DateTime? filenameDate(String filename) {
    final candidates = _parseFilenameDates(filename);
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }

  static List<DateTime> _parseFilenameDates(String filename) {
    final name = _basename(filename.trim());
    if (name.isEmpty) return const [];

    final candidates = <DateTime>[];

    const spanishMonths = {
      'ene': 1,
      'enero': 1,
      'feb': 2,
      'febrero': 2,
      'mar': 3,
      'marzo': 3,
      'abr': 4,
      'abril': 4,
      'may': 5,
      'mayo': 5,
      'jun': 6,
      'junio': 6,
      'jul': 7,
      'julio': 7,
      'ago': 8,
      'agosto': 8,
      'sep': 9,
      'sept': 9,
      'set': 9,
      'septiembre': 9,
      'setiembre': 9,
      'oct': 10,
      'octubre': 10,
      'nov': 11,
      'noviembre': 11,
      'dic': 12,
      'diciembre': 12,
    };
    final spanish = RegExp(
      r'(^|[^A-Za-z0-9])(\d{1,2})[\s._-]+'
      r'(ene(?:ro)?|feb(?:rero)?|mar(?:zo)?|abr(?:il)?|may(?:o)?|'
      r'jun(?:io)?|jul(?:io)?|ago(?:sto)?|sep(?:t(?:iembre)?)?|'
      r'set(?:iembre)?|oct(?:ubre)?|nov(?:iembre)?|dic(?:iembre)?)'
      r'[\s,._-]+(\d{4})'
      r'(?:[, ]+(\d{1,2})[:._-](\d{2})(?:[:._-](\d{2}))?'
      r'\s*(a\.?\s*m\.?|p\.?\s*m\.?)?)?',
      caseSensitive: false,
    );
    for (final match in spanish.allMatches(name)) {
      final month = spanishMonths[match.group(3)!.toLowerCase()];
      if (month == null) continue;

      var hour = int.tryParse(match.group(5) ?? '') ?? 0;
      final minute = int.tryParse(match.group(6) ?? '') ?? 0;
      final second = int.tryParse(match.group(7) ?? '') ?? 0;
      final meridiem =
          (match.group(8) ?? '').replaceAll(RegExp(r'[\s.]'), '').toLowerCase();
      if (meridiem.isNotEmpty) {
        if (hour < 1 || hour > 12) continue;
        hour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
      }

      final date = _makeDate(
        year: int.parse(match.group(4)!),
        month: month,
        day: int.parse(match.group(2)!),
        hour: hour,
        minute: minute,
        second: second,
      );
      if (date != null) candidates.add(date);
    }

    // ISO-like names, including WhatsApp's "YYYY-MM-DD at HH.mm.ss" format.
    final iso = RegExp(
      r'(^|[^0-9])(\d{4})[-._/](\d{1,2})[-._/](\d{1,2})'
      r'(?:[ T_-]+(?:at[ T_-]+)?(\d{1,2})[:._-](\d{2})(?:[:._-](\d{2}))?'
      r'(?:\s*(Z|[+-]\d{2}:?\d{2}))?)?(?!\d)',
      caseSensitive: false,
    );
    for (final match in iso.allMatches(name)) {
      final date = _makeDate(
        year: int.parse(match.group(2)!),
        month: int.parse(match.group(3)!),
        day: int.parse(match.group(4)!),
        hour: int.tryParse(match.group(5) ?? '') ?? 0,
        minute: int.tryParse(match.group(6) ?? '') ?? 0,
        second: int.tryParse(match.group(7) ?? '') ?? 0,
        offset: match.group(8),
      );
      if (date != null) candidates.add(date);
    }

    // Camera and messaging app names often use YYYYMMDD[HHMMSS].
    final compact = RegExp(
      r'(^|[^0-9])(\d{4})(\d{2})(\d{2})(?:[_-]?(\d{2})(\d{2})(\d{2}))?(?!\d)',
    );
    for (final match in compact.allMatches(name)) {
      final date = _makeDate(
        year: int.parse(match.group(2)!),
        month: int.parse(match.group(3)!),
        day: int.parse(match.group(4)!),
        hour: int.tryParse(match.group(5) ?? '') ?? 0,
        minute: int.tryParse(match.group(6) ?? '') ?? 0,
        second: int.tryParse(match.group(7) ?? '') ?? 0,
      );
      if (date != null) candidates.add(date);
    }

    // Numeric day/month names are accepted only when the ordering is clear.
    final numeric = RegExp(
      r'(^|[^0-9])(\d{1,2})[._/-](\d{1,2})[._/-](\d{4})'
      r'(?:[ T_-]+(\d{1,2})[:._-](\d{2})(?:[:._-](\d{2}))?)?(?!\d)',
    );
    for (final match in numeric.allMatches(name)) {
      final first = int.parse(match.group(2)!);
      final second = int.parse(match.group(3)!);
      final int day;
      final int month;
      if (first > 12 && second <= 12) {
        day = first;
        month = second;
      } else if (second > 12 && first <= 12) {
        day = second;
        month = first;
      } else {
        continue;
      }

      final date = _makeDate(
        year: int.parse(match.group(4)!),
        month: month,
        day: day,
        hour: int.tryParse(match.group(5) ?? '') ?? 0,
        minute: int.tryParse(match.group(6) ?? '') ?? 0,
        second: int.tryParse(match.group(7) ?? '') ?? 0,
      );
      if (date != null) candidates.add(date);
    }

    return candidates.toSet().toList(growable: true);
  }

  static DateTime? _makeDate({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
    String? offset,
  }) {
    final now = DateTime.now().toUtc();
    if (year < 1900 ||
        year > now.year + 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        second < 0 ||
        second > 59) {
      return null;
    }

    final local = DateTime(year, month, day, hour, minute, second);
    if (local.year != year ||
        local.month != month ||
        local.day != day ||
        local.hour != hour ||
        local.minute != minute ||
        local.second != second) {
      return null;
    }

    DateTime resolved;
    if (offset == null || offset.isEmpty) {
      resolved = local.toUtc();
    } else if (offset.toUpperCase() == 'Z') {
      resolved = DateTime.utc(year, month, day, hour, minute, second);
    } else {
      final parsed = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(offset);
      if (parsed == null) return null;
      final offsetHours = int.parse(parsed.group(2)!);
      final offsetMinutes = int.parse(parsed.group(3)!);
      if (offsetHours > 14 ||
          offsetMinutes > 59 ||
          (offsetHours == 14 && offsetMinutes != 0)) {
        return null;
      }
      var totalMinutes = offsetHours * 60 + offsetMinutes;
      if (parsed.group(1) == '-') totalMinutes = -totalMinutes;
      resolved = DateTime.utc(year, month, day, hour, minute, second)
          .subtract(Duration(minutes: totalMinutes));
    }

    if (resolved.isAfter(now.add(const Duration(days: 1)))) return null;
    return resolved;
  }

  Future<List<DateTime>> _readExifDates(Uint8List bytes) async {
    try {
      final data = await exif.readExifFromBytes(bytes);
      if (data.isEmpty) return const [];

      final offset = _tagValue(data, const [
        'EXIF OffsetTimeOriginal',
        'EXIF OffsetTimeDigitized',
        'Image OffsetTime',
      ]);
      final candidates = <DateTime>[];
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        if (!(key.contains('datetimeoriginal') ||
            key.contains('datetimedigitized') ||
            key == 'image datetime' ||
            key.contains('gps datestamp'))) {
          continue;
        }
        final value = entry.value.printable.trim();
        final parsed = _parseExifDate(value, offset: offset);
        if (parsed != null) candidates.add(parsed);
      }
      return candidates.toSet().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  DateTime? _parseExifDate(String value, {String? offset}) {
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(value);
    if (match == null) return null;
    return _makeDate(
      year: int.parse(match.group(1)!),
      month: int.parse(match.group(2)!),
      day: int.parse(match.group(3)!),
      hour: int.parse(match.group(4)!),
      minute: int.parse(match.group(5)!),
      second: int.parse(match.group(6)!),
      offset: offset,
    );
  }

  String? _tagValue(Map<String, exif.IfdTag> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.printable.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  PhotoDateResolution _resolve({
    required List<DateTime> metadataDates,
    required String? filename,
    required DateTime? fallbackModifiedTime,
  }) {
    final metadata = metadataDates.map((date) => date.toUtc()).toList()..sort();
    final nameCandidates =
        filename == null ? <DateTime>[] : _parseFilenameDates(filename).toList()
          ..sort();

    final DateTime? metadataDate = metadata.isEmpty ? null : metadata.first;
    final DateTime? filenameDate =
        nameCandidates.isEmpty ? null : nameCandidates.first;
    final modified = fallbackModifiedTime?.toUtc();
    final now = DateTime.now().toUtc();
    final validModified = modified != null &&
            modified.year >= 1900 &&
            !modified.isAfter(now.add(const Duration(days: 1)))
        ? modified
        : null;
    DateTime? createdAt;
    String source;

    if (metadataDate != null && filenameDate != null) {
      if (metadataDate.isBefore(filenameDate)) {
        createdAt = metadataDate;
        source = 'metadata';
      } else {
        createdAt = filenameDate;
        source = 'filename';
      }
    } else if (metadataDate != null) {
      createdAt = metadataDate;
      source = 'metadata';
    } else if (filenameDate != null) {
      createdAt = filenameDate;
      source = 'filename';
    } else if (validModified != null) {
      createdAt = validModified;
      source = 'file_modified';
    } else {
      createdAt = DateTime.now().toUtc();
      source = 'upload_time';
    }

    final safeFilename = filename == null ? '' : _basename(filename).trim();
    return PhotoDateResolution(
      createdAt: createdAt,
      metadataDate: metadataDate,
      filenameDate: filenameDate,
      source: source,
      needsAiFilenameResolution:
          safeFilename.isNotEmpty && filenameDate == null,
      deviceUtcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}
