import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Compose a JPEG photo with a PNG overlay, applying optional mirror and aspect crop.
Uint8List composeJpegWithOverlayBytes({
  required Uint8List baseJpegBytes,
  required Uint8List overlayImageBytes,
  required bool mirrorHorizontally,
  required double targetAspectRatio,
  int quality = 92,
}) {
  final base = img.decodeImage(baseJpegBytes);
  if (base == null) {
    throw StateError('Failed to decode captured photo');
  }
  final overlay = img.decodeImage(overlayImageBytes);
  if (overlay == null) {
    throw StateError('Failed to decode overlay image');
  }

  img.Image composed = img.bakeOrientation(base);
  composed = rotateToMatchAspect(
    composed,
    targetAspect: targetAspectRatio,
  );
  if (mirrorHorizontally) {
    composed = img.flipHorizontal(composed);
  }
  composed = centerCropToAspect(composed, targetAspectRatio);

  final resizedOverlay = img.copyResize(
    overlay,
    width: composed.width,
    height: composed.height,
    interpolation: img.Interpolation.average,
  );

  img.compositeImage(composed, resizedOverlay, dstX: 0, dstY: 0);
  final outBytes = img.encodeJpg(composed, quality: quality);
  return Uint8List.fromList(outBytes);
}

img.Image rotateToMatchAspect(
  img.Image src, {
  required double targetAspect,
}) {
  if (targetAspect <= 0) return src;
  final isTargetLandscape = targetAspect >= 1;
  final isSrcLandscape = src.width >= src.height;
  if (isTargetLandscape == isSrcLandscape) return src;
  // Rotate 90 degrees when orientation/aspect differs
  return img.copyRotate(src, angle: 90);
}

img.Image centerCropToAspect(img.Image src, double aspectRatio) {
  if (aspectRatio <= 0) return src;
  final srcW = src.width;
  final srcH = src.height;
  if (srcW <= 0 || srcH <= 0) return src;

  final srcAspect = srcW / srcH;
  if ((srcAspect - aspectRatio).abs() < 0.0001) {
    return src;
  }

  if (srcAspect > aspectRatio) {
    final targetW = (srcH * aspectRatio).round().clamp(1, srcW);
    final x = ((srcW - targetW) / 2).round();
    return img.copyCrop(src, x: x, y: 0, width: targetW, height: srcH);
  }

  final targetH = (srcW / aspectRatio).round().clamp(1, srcH);
  final y = ((srcH - targetH) / 2).round();
  return img.copyCrop(src, x: 0, y: y, width: srcW, height: targetH);
}
