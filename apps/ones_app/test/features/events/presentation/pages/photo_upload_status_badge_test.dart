import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/photos/presentation/photo_upload_status_badge.dart';

void main() {
  testWidgets('queued photo has an accessible upload indicator',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhotoUploadStatusBadge(status: 'pending'),
        ),
      ),
    );

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Foto guardada en el dispositivo; pendiente de subir',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uploading photo shows its current percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhotoUploadStatusBadge(status: 'uploading', progress: 0.42),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('failed photo remains retryable from its status badge',
      (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoUploadStatusBadge(
            status: 'failed',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(retryCount, 1);
  });
}
