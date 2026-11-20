import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/photos/presentation/pages/photo_import_file_utils.dart';

void main() {
  group('jpegImportFileName', () {
    test('replaces an image extension with jpg', () {
      expect(jpegImportFileName('IMG_1234.HEIC'), 'IMG_1234.jpg');
    });

    test('keeps the base name when given a path', () {
      expect(
        jpegImportFileName(r'C:\Photos\WhatsApp Image 2026-11-11.png'),
        'WhatsApp Image 2026-11-11.jpg',
      );
    });
  });
}
