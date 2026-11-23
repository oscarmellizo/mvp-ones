import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

Uint8List pngToJpegBytes(Uint8List input, {int quality = 90}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw StateError('Failed to decode image');
  }
  final baked = img.bakeOrientation(decoded);
  final out = img.encodeJpg(baked, quality: quality);
  return Uint8List.fromList(out);
}

/// Converts an image to JPEG using the platform codec for decoding.
/// Needed for formats the `image` package cannot decode (e.g. HEIC/HEIF),
/// which the engine still decodes natively on iOS/Android.
Future<Uint8List> platformImageToJpegBytes(
  Uint8List input, {
  int quality = 90,
}) async {
  final codec = await ui.instantiateImageCodec(input);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Failed to decode image');
      }
      return pngToJpegBytes(
        Uint8List.fromList(png.buffer.asUint8List()),
        quality: quality,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
