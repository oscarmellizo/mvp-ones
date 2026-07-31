import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List pngToJpegBytes(Uint8List input, {int quality = 90}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw StateError('Failed to decode PNG');
  }
  final baked = img.bakeOrientation(decoded);
  final out = img.encodeJpg(baked, quality: quality);
  return Uint8List.fromList(out);
}
