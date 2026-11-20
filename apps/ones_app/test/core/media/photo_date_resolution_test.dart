import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/media/photo_date_resolution.dart';

void main() {
  group('PhotoDateResolver.filenameDate', () {
    test('parses WhatsApp human and compact filenames', () {
      final human = PhotoDateResolver.filenameDate(
        'WhatsApp Image 2024-06-27 at 10.31.12.jpg',
      );
      final compact = PhotoDateResolver.filenameDate('IMG-20240627-WA0001.jpg');

      expect(human, isNotNull);
      expect(human!.toLocal(), DateTime(2024, 6, 27, 10, 31, 12));
      expect(compact!.toLocal(), DateTime(2024, 6, 27));
    });

    test('parses Spanish month names and localized AM/PM times', () {
      final first = PhotoDateResolver.filenameDate(
        'Test 6 dic 2025, 02_37_56 a.m. - copia.png',
      );
      final second = PhotoDateResolver.filenameDate(
        'Test 6 dic 2025, 02_44_04 a.m. - copia.png',
      );
      final afternoon = PhotoDateResolver.filenameDate(
        'Foto 6 diciembre 2025, 02_37_56 p.m..jpg',
      );

      expect(first!.toLocal(), DateTime(2025, 12, 6, 2, 37, 56));
      expect(second!.toLocal(), DateTime(2025, 12, 6, 2, 44, 4));
      expect(afternoon!.toLocal(), DateTime(2025, 12, 6, 14, 37, 56));
    });

    test('chooses the oldest date and rejects impossible dates', () {
      final earliest = PhotoDateResolver.filenameDate(
        'copy_2024-06-27_2022-05-03.jpg',
      );
      final invalid = PhotoDateResolver.filenameDate('IMG_20240230.jpg');

      expect(earliest!.toLocal(), DateTime(2022, 5, 3));
      expect(invalid, isNull);
    });

    test('does not guess ambiguous day/month order', () {
      expect(PhotoDateResolver.filenameDate('03-04-2024.jpg'), isNull);
      expect(
        PhotoDateResolver.filenameDate('31-03-2024.jpg')!.toLocal(),
        DateTime(2024, 3, 31),
      );
    });

    test('honors an explicit UTC offset', () {
      final date = PhotoDateResolver.filenameDate(
        'photo_2024-06-27T10:00:00+0200.jpg',
      );

      expect(date, DateTime.utc(2024, 6, 27, 8));
    });

    test('marks unknown filenames for AI and keeps upload time as fallback',
        () async {
      final before = DateTime.now().toUtc();
      final result = await const PhotoDateResolver().resolveFromBytes(
        bytes: Uint8List(0),
        filename: 'shared-photo.jpg',
      );

      expect(result.needsAiFilenameResolution, isTrue);
      expect(result.metadataDate, isNull);
      expect(result.filenameDate, isNull);
      expect(result.source, 'upload_time');
      expect(
          result.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
    });
  });
}
