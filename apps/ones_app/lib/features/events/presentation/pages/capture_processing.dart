import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

enum CaptureOrientation { portrait, landscape }

class NormalizedCapture {
  final Uint8List bytes;
  final int width;
  final int height;
  final CaptureOrientation orientation;

  const NormalizedCapture(this.bytes, this.width, this.height, this.orientation);
}

class CaptureProcessingInput {
  final Uint8List bytes;
  final CaptureOrientation orientation;
  final DeviceOrientation? deviceOrientation;
  final bool invertLandscapeRotation;

  const CaptureProcessingInput(
    this.bytes,
    this.orientation,
    this.deviceOrientation,
    this.invertLandscapeRotation,
  );
}

NormalizedCapture normalizeNativeCapture(CaptureProcessingInput input) =>
    normalizeCapturedJpeg(
      bytes: input.bytes,
      orientation: input.orientation,
      deviceOrientation: input.deviceOrientation,
      invertLandscapeRotation: input.invertLandscapeRotation,
    );

CaptureOrientation resolveCaptureOrientation({
  required double viewportAspect,
  DeviceOrientation? deviceOrientation,
  int? imageWidth,
  int? imageHeight,
  CaptureOrientation? forcedOrientation,
}) {
  if (forcedOrientation != null) return forcedOrientation;
  if (deviceOrientation == DeviceOrientation.landscapeLeft ||
      deviceOrientation == DeviceOrientation.landscapeRight) {
    return CaptureOrientation.landscape;
  }
  if (viewportAspect > 1.05) return CaptureOrientation.landscape;
  if (deviceOrientation == DeviceOrientation.portraitUp ||
      deviceOrientation == DeviceOrientation.portraitDown) {
    return CaptureOrientation.portrait;
  }
  if (viewportAspect > 0 && viewportAspect < 0.95) {
    return CaptureOrientation.portrait;
  }
  if (imageWidth != null && imageHeight != null) {
    return imageWidth > imageHeight
        ? CaptureOrientation.landscape
        : CaptureOrientation.portrait;
  }
  return CaptureOrientation.portrait;
}

NormalizedCapture normalizeCapturedJpeg({
  required Uint8List bytes,
  CaptureOrientation? orientation,
  double viewportAspect = 0,
  DeviceOrientation? deviceOrientation,
  bool invertLandscapeRotation = false,
  int maxDimension = 0,
}) {
  final image = img.decodeImage(bytes);
  if (image == null) throw StateError('Failed to decode captured photo');
  var normalized = img.bakeOrientation(image);
  final chosenOrientation = orientation ?? resolveCaptureOrientation(
    viewportAspect: viewportAspect,
    deviceOrientation: deviceOrientation,
    imageWidth: normalized.width,
    imageHeight: normalized.height,
  );
  final shouldBeLandscape = chosenOrientation == CaptureOrientation.landscape;
  if ((normalized.width > normalized.height) != shouldBeLandscape) {
    final angle = switch (deviceOrientation) {
      DeviceOrientation.landscapeLeft => invertLandscapeRotation ? 90 : 270,
      DeviceOrientation.landscapeRight => invertLandscapeRotation ? 270 : 90,
      _ => 90,
    };
    normalized = img.copyRotate(normalized, angle: angle);
  }
  if (maxDimension > 0 &&
      (normalized.width > maxDimension || normalized.height > maxDimension)) {
    final ratio = maxDimension /
        (normalized.width > normalized.height
            ? normalized.width
            : normalized.height);
    normalized = img.copyResize(
      normalized,
      width: (normalized.width * ratio).round(),
      height: (normalized.height * ratio).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return NormalizedCapture(
    Uint8List.fromList(img.encodeJpg(normalized, quality: 92)),
    normalized.width,
    normalized.height,
    chosenOrientation,
  );
}

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
