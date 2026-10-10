import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:ones_app/features/events/presentation/pages/capture_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/presentation/pages/photo_capture_web_page.dart';

void main() {
  for (final opacity in [0.0, 0.8]) {
    testWidgets('la capa de obturador no bloquea taps con opacidad $opacity',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: IconButton(
                onPressed: () => taps++,
                icon: const Icon(Icons.camera),
              )),
              CameraShutterOverlay(
                animation: AlwaysStoppedAnimation<double>(opacity),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.camera));
      expect(taps, 1);
    });
  }

  test('web prioriza orientación física y conserva la regla nativa', () {
    expect(
      resolveCaptureOrientation(
        viewportAspect: 0.6,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        imageWidth: 80,
        imageHeight: 120,
      ),
      CaptureOrientation.landscape,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 0.6,
        imageWidth: 120,
        imageHeight: 80,
      ),
      CaptureOrientation.portrait,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 2.0,
        deviceOrientation: DeviceOrientation.portraitUp,
        prioritizeDeviceOrientation: true,
      ),
      CaptureOrientation.portrait,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 2.0,
        deviceOrientation: DeviceOrientation.portraitUp,
      ),
      CaptureOrientation.landscape,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 1.0,
        deviceOrientation: DeviceOrientation.portraitUp,
        imageWidth: 120,
        imageHeight: 80,
      ),
      CaptureOrientation.portrait,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 1.0,
        imageWidth: 120,
        imageHeight: 80,
      ),
      CaptureOrientation.landscape,
    );
    expect(
      resolveCaptureOrientation(
        viewportAspect: 0.6,
        forcedOrientation: CaptureOrientation.landscape,
      ),
      CaptureOrientation.landscape,
    );
  });

  for (final orientation in CaptureOrientation.values) {
    test('JPEG sin marco guarda píxeles $orientation', () {
      final original = img.Image(width: 120, height: 80);
      final bytes = Uint8List.fromList(img.encodeJpg(original));
      final processed = normalizeCapturedJpeg(
        bytes: bytes,
        orientation: orientation,
      );
      final decoded = img.decodeJpg(processed.bytes)!;
      expect(decoded.width, processed.width);
      expect(decoded.height, processed.height);
      expect(decoded.width > decoded.height,
          orientation == CaptureOrientation.landscape);
      expect(decoded.exif.imageIfd.orientation, isNot(6));
    });
  }

  test('orientación EXIF 8 se normaliza sin segunda rotación', () {
    final source = img.Image(width: 80, height: 120);
    source.exif.imageIfd.orientation = 8;
    final normalized = normalizeCapturedJpeg(
      bytes: Uint8List.fromList(img.encodeJpg(source)),
      orientation: CaptureOrientation.landscape,
    );
    expect(normalized.width, greaterThan(normalized.height));
    expect(img.decodeJpg(normalized.bytes)!.exif.imageIfd.orientation, isNot(8));
  });

  test('landscapeLeft y landscapeRight giran en sentidos opuestos', () {
    final source = img.Image(width: 120, height: 80);
    img.fillRect(source, x1: 0, y1: 0, x2: 59, y2: 79,
        color: img.ColorRgb8(255, 0, 0));
    img.fillRect(source, x1: 60, y1: 0, x2: 119, y2: 79,
        color: img.ColorRgb8(0, 0, 255));
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final left = normalizeCapturedJpeg(
      bytes: bytes,
      orientation: CaptureOrientation.portrait,
      deviceOrientation: DeviceOrientation.landscapeLeft,
    );
    final right = normalizeCapturedJpeg(
      bytes: bytes,
      orientation: CaptureOrientation.portrait,
      deviceOrientation: DeviceOrientation.landscapeRight,
    );
    expect(left.width, lessThan(left.height));
    expect(right.width, lessThan(right.height));
    expect(left.bytes, isNot(equals(right.bytes)));
  });

  test('reduce fotografías grandes antes de subir sin cambiar orientación', () {
    final normalized = normalizeCapturedJpeg(
      bytes: Uint8List.fromList(img.encodeJpg(img.Image(width: 300, height: 200))),
      orientation: CaptureOrientation.landscape,
      maxDimension: 120,
    );
    expect(normalized.width, 120);
    expect(normalized.height, 80);
  });

  test('bake EXIF y marco horizontal una sola vez', () {
    final original = img.Image(width: 80, height: 120);
    original.exif.imageIfd.orientation = 6;
    final bytes = Uint8List.fromList(img.encodeJpg(original));
    final normalized = normalizeCapturedJpeg(
      bytes: bytes,
      orientation: CaptureOrientation.landscape,
    );
    expect(normalized.width, greaterThan(normalized.height));
    final overlay = Uint8List.fromList(img.encodePng(img.Image(
      width: 120, height: 80,
    )));
    final framed = composeJpegWithOverlayBytes(
      baseJpegBytes: normalized.bytes,
      overlayImageBytes: overlay,
      mirrorHorizontally: false,
      targetAspectRatio: 1.5,
    );
    final decoded = img.decodeJpg(framed)!;
    expect(decoded.width, greaterThan(decoded.height));
    expect(decoded.exif.imageIfd.orientation, isNot(6));
  });
}
