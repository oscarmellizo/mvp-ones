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
    String source = 'now';

    final exifDates = await _readExifDatesList(bytes);
    if (exifDates.isNotEmpty) {
      final e = exifDates.reduce((a, b) => a.isBefore(b) ? a : b).toUtc();
      result = e;
      source = 'exif';
    }

    final nameCandidates = _parseDatesFromFilenameAll(filename ?? '');
    if (nameCandidates.isNotEmpty) {
      final n = nameCandidates.reduce((a, b) => a.isBefore(b) ? a : b).toUtc();
      if (result == null || n.isBefore(result)) {
        result = n;
        source = 'filename';
      }
    }

    if (fallbackModifiedTime != null) {
      final m = fallbackModifiedTime.toUtc();
      if (result == null || m.isBefore(result)) {
        result = m;
        source = 'mtime';
      }
    }

    final chosen = result ?? DateTime.now().toUtc();
    final exifStr = exifDates.map((d) => d.toUtc().toIso8601String()).join(',');
    final nameListStr = nameCandidates.map((d) => d.toUtc().toIso8601String()).join(',');
    final mtimeStr = fallbackModifiedTime?.toUtc().toIso8601String();
    Map<String, String> exifRaw = const {};
    try {
      exifRaw = await _readExifDateLikeEntries(bytes);
    } catch (_) {}
    final exifRawStr = exifRaw.entries.map((e) => '${e.key}=${e.value}').join('; ');
    print('photo_meta: bytes filename=${filename ?? ''} exif_raw=[$exifRawStr] exif_candidates=[$exifStr] name_candidates=[$nameListStr] mtime=$mtimeStr chosen=${chosen.toIso8601String()} via=$source');
    return chosen;
  }

  Future<DateTime> createdAtFromFile({
    required File file,
    String? filename,
  }) async {
    DateTime? result;
    String source = 'now';
    try {
      final bytes = await file.readAsBytes();
      final exifDates = await _readExifDatesList(bytes);
      if (exifDates.isNotEmpty) {
        final e = exifDates.reduce((a, b) => a.isBefore(b) ? a : b).toUtc();
        result = e;
        source = 'exif';
      }
    } catch (_) {}

    final nameCandidates = _parseDatesFromFilenameAll(filename ?? file.uri.pathSegments.last);
    if (nameCandidates.isNotEmpty) {
      final n = nameCandidates.reduce((a, b) => a.isBefore(b) ? a : b).toUtc();
      if (result == null || n.isBefore(result)) {
        result = n;
        source = 'filename';
      }
    }

    try {
      final m = await file.lastModified();
      final mu = m.toUtc();
      if (result == null || mu.isBefore(result)) {
        result = mu;
        source = 'mtime';
      }
    } catch (_) {}

    final chosen = result ?? DateTime.now().toUtc();
    List<DateTime> exifList = const [];
    Map<String, String> exifRaw = const {};
    try {
      final b = await file.readAsBytes();
      exifList = await _readExifDatesList(b);
      exifRaw = await _readExifDateLikeEntries(b);
    } catch (_) {}
    final exifStr = exifList.map((d) => d.toUtc().toIso8601String()).join(',');
    final nameListStr = nameCandidates.map((d) => d.toUtc().toIso8601String()).join(',');
    DateTime? mtime;
    try {
      mtime = (await file.lastModified()).toUtc();
    } catch (_) {}
    final mtimeStr = mtime?.toIso8601String();
    final exifRawStr = exifRaw.entries.map((e) => '${e.key}=${e.value}').join('; ');
    print('photo_meta: file path=${file.path} filename=${filename ?? file.uri.pathSegments.last} exif_raw=[$exifRawStr] exif_candidates=[$exifStr] name_candidates=[$nameListStr] mtime=$mtimeStr chosen=${chosen.toIso8601String()} via=$source');
    return chosen;
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

  Future<List<DateTime>> _readExifDatesList(Uint8List bytes) async {
    try {
      final data = await exif.readExifFromBytes(bytes);
      if (data.isEmpty) return const [];
      final out = <DateTime>[];
      for (final entry in data.entries) {
        final value = entry.value.printable.trim();
        final candidates = _extractDateCandidatesFromText(value);
        for (final c in candidates) {
          out.add(c.toUtc());
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, String>> _readExifDateLikeEntries(Uint8List bytes) async {
    try {
      final data = await exif.readExifFromBytes(bytes);
      if (data.isEmpty) return const {};
      final out = <String, String>{};
      for (final entry in data.entries) {
        final k = entry.key;
        final v = entry.value.printable.trim();
        if (_looksLikeDateString(v) || k.contains('Date') || k.contains('Time') || k.contains('Create') || k.contains('Modify')) {
          out[k] = v;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  bool _looksLikeDateString(String s) {
    final r1 = RegExp(r'\d{4}[:\-\._]\d{2}[:\-\._]\d{2}');
    final r2 = RegExp(r'\d{8}[T _-]?\d{6}');
    final r3 = RegExp(r'\d{2}[:\-\._]\d{2}[:\-\._]\d{4}');
    return r1.hasMatch(s) || r2.hasMatch(s) || r3.hasMatch(s);
  }

  List<DateTime> _extractDateCandidatesFromText(String text) {
    final out = <DateTime>[];
    final exifRe = RegExp(r'(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(?:\s*([+-]\d{2}):?(\d{2}))?');
    for (final m in exifRe.allMatches(text)) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final hh = int.parse(m.group(4)!);
      final mm = int.parse(m.group(5)!);
      final ss = int.parse(m.group(6)!);
      final tzH = m.group(8);
      final tzM = m.group(9);
      if (tzH != null && tzH.isNotEmpty && tzM != null && tzM.isNotEmpty) {
        final sign = tzH.startsWith('-') ? '-' : '+';
        final offH = tzH.replaceAll('+', '').replaceAll('-', '');
        final iso = '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}T${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}$sign${offH.padLeft(2, '0')}:${tzM.padLeft(2, '0')}';
        try { out.add(DateTime.parse(iso).toUtc()); } catch (_) {}
      } else {
        out.add(DateTime(y, mo, d, hh, mm, ss).toUtc());
      }
    }
    final isoLike = RegExp(r'(\d{4})[\-\._](\d{2})[\-\._](\d{2})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?');
    for (final m in isoLike.allMatches(text)) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final hh = int.tryParse(m.group(4) ?? '') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '') ?? 0;
      out.add(DateTime(y, mo, d, hh, mm, ss).toUtc());
    }
    // Date-only variants
    final exifDateOnly = RegExp(r'(\d{4}):(\d{2}):(\d{2})(?![0-9:])');
    for (final m in exifDateOnly.allMatches(text)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        0,
        0,
        0,
      ).toUtc());
    }
    final isoSlashDateOnly = RegExp(r'(\d{4})/(\d{2})/(\d{2})(?![0-9/])');
    for (final m in isoSlashDateOnly.allMatches(text)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        0,
        0,
        0,
      ).toUtc());
    }
    final compactDateOnly = RegExp(r'\b(\d{4})(\d{2})(\d{2})\b');
    for (final m in compactDateOnly.allMatches(text)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        0,
        0,
        0,
      ).toUtc());
    }
    final compact = RegExp(r'(\d{4})(\d{2})(\d{2})[_-]?(\d{2})(\d{2})(\d{2})');
    for (final m in compact.allMatches(text)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ).toUtc());
    }
    final dmy = RegExp(r'(\d{2})[\-\._](\d{2})[\-\._](\d{4})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?');
    for (final m in dmy.allMatches(text)) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      final hh = int.tryParse(m.group(4) ?? '') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '') ?? 0;
      out.add(DateTime(y, mo, d, hh, mm, ss).toUtc());
    }
    return out;
  }

  List<DateTime> _parseDatesFromFilenameAll(String name) {
    if (name.isEmpty) return const [];
    final out = <DateTime>[];
    final waTs = RegExp(r'(\d{4})-(\d{2})-(\d{2}).*?(\d{2})[\.:_](\d{2})[\.:_](\d{2})');
    for (final m in waTs.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ));
    }
    final ymdhms = RegExp(r'(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})');
    for (final m in ymdhms.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ));
    }
    final isoLike = RegExp(r'(\d{4})[\-\._](\d{2})[\-\._](\d{2})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?');
    for (final m in isoLike.allMatches(name)) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final hh = int.tryParse(m.group(4) ?? '') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '') ?? 0;
      out.add(DateTime(y, mo, d, hh, mm, ss));
    }
    final dmy = RegExp(r'(\d{2})[\-\._](\d{2})[\-\._](\d{4})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?');
    for (final m in dmy.allMatches(name)) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      final hh = int.tryParse(m.group(4) ?? '') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '') ?? 0;
      out.add(DateTime(y, mo, d, hh, mm, ss));
    }
    final waImg = RegExp(r'IMG[-_](\d{4})(\d{2})(\d{2})[-_](?:WA\w*\d*)');
    for (final m in waImg.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ));
    }
    final screenshot1 = RegExp(r'(?:Screenshot|SCREENSHOT)[-_]?(\d{4})(\d{2})(\d{2})[-_](\d{2})(\d{2})(\d{2})');
    for (final m in screenshot1.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ));
    }
    final photoDash = RegExp(r'(\d{4})-(\d{2})-(\d{2})[^0-9]+(\d{2})[-_](\d{2})(?:[-_](\d{2}))?');
    for (final m in photoDash.allMatches(name)) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final hh = int.tryParse(m.group(4) ?? '') ?? 0;
      final mm = int.tryParse(m.group(5) ?? '') ?? 0;
      final ss = int.tryParse(m.group(6) ?? '') ?? 0;
      out.add(DateTime(y, mo, d, hh, mm, ss));
    }
    // Pure date-only patterns in filename
    final pureIsoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    for (final m in pureIsoDate.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ));
    }
    final pureCompactDate = RegExp(r'\b(\d{4})(\d{2})(\d{2})\b');
    for (final m in pureCompactDate.allMatches(name)) {
      out.add(DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      ));
    }
    return out;
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

    DateTime? earliest;

    final waTs = RegExp(r'(\d{4})-(\d{2})-(\d{2}).*?(\d{2})[\.:_](\d{2})[\.:_](\d{2})')
        .firstMatch(name);
    if (waTs != null) {
      final dt = DateTime(
        int.parse(waTs.group(1)!),
        int.parse(waTs.group(2)!),
        int.parse(waTs.group(3)!),
        int.parse(waTs.group(4)!),
        int.parse(waTs.group(5)!),
        int.parse(waTs.group(6)!),
      );
      earliest = dt;
    }

    final ymdhms = RegExp(r'(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})')
        .firstMatch(name);
    if (ymdhms != null) {
      final dt = DateTime(
        int.parse(ymdhms.group(1)!),
        int.parse(ymdhms.group(2)!),
        int.parse(ymdhms.group(3)!),
        int.parse(ymdhms.group(4)!),
        int.parse(ymdhms.group(5)!),
        int.parse(ymdhms.group(6)!),
      );
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    final isoLike = RegExp(r'(\d{4})[\-\._](\d{2})[\-\._](\d{2})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?')
        .firstMatch(name);
    if (isoLike != null) {
      final y = int.parse(isoLike.group(1)!);
      final m = int.parse(isoLike.group(2)!);
      final d = int.parse(isoLike.group(3)!);
      final hh = int.tryParse(isoLike.group(4) ?? '') ?? 0;
      final mm = int.tryParse(isoLike.group(5) ?? '') ?? 0;
      final ss = int.tryParse(isoLike.group(6) ?? '') ?? 0;
      final dt = DateTime(y, m, d, hh, mm, ss);
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    final dmy = RegExp(r'(\d{2})[\-\._](\d{2})[\-\._](\d{4})(?:[^0-9]+(\d{2})[\.:_](\d{2})(?:[\.:_](\d{2}))?)?')
        .firstMatch(name);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final m = int.parse(dmy.group(2)!);
      final y = int.parse(dmy.group(3)!);
      final hh = int.tryParse(dmy.group(4) ?? '') ?? 0;
      final mm = int.tryParse(dmy.group(5) ?? '') ?? 0;
      final ss = int.tryParse(dmy.group(6) ?? '') ?? 0;
      final dt = DateTime(y, m, d, hh, mm, ss);
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    final waImg = RegExp(r'IMG[-_](\d{4})(\d{2})(\d{2})[-_](?:WA\w*\d*)')
        .firstMatch(name);
    if (waImg != null) {
      final dt = DateTime(
        int.parse(waImg.group(1)!),
        int.parse(waImg.group(2)!),
        int.parse(waImg.group(3)!),
      );
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    final screenshot1 = RegExp(r'(?:Screenshot|SCREENSHOT)[-_]?(\d{4})(\d{2})(\d{2})[-_](\d{2})(\d{2})(\d{2})')
        .firstMatch(name);
    if (screenshot1 != null) {
      final dt = DateTime(
        int.parse(screenshot1.group(1)!),
        int.parse(screenshot1.group(2)!),
        int.parse(screenshot1.group(3)!),
        int.parse(screenshot1.group(4)!),
        int.parse(screenshot1.group(5)!),
        int.parse(screenshot1.group(6)!),
      );
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    final photoDash = RegExp(r'(\d{4})-(\d{2})-(\d{2})[^0-9]+(\d{2})[-_](\d{2})(?:[-_](\d{2}))?')
        .firstMatch(name);
    if (photoDash != null) {
      final y = int.parse(photoDash.group(1)!);
      final m = int.parse(photoDash.group(2)!);
      final d = int.parse(photoDash.group(3)!);
      final hh = int.tryParse(photoDash.group(4) ?? '') ?? 0;
      final mm = int.tryParse(photoDash.group(5) ?? '') ?? 0;
      final ss = int.tryParse(photoDash.group(6) ?? '') ?? 0;
      final dt = DateTime(y, m, d, hh, mm, ss);
      earliest = (earliest == null || dt.isBefore(earliest!)) ? dt : earliest;
    }

    return earliest;
  }
}
