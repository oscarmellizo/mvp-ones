import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/photos/presentation/pages/photo_import_mobile_sheet.dart';
import 'package:provider/provider.dart';

class _Translations extends Mock implements TranslationsService {}

void main() {
  testWidgets(
    'iOS photo import offers Photos and Files pickers',
    (tester) async {
      final translations = _Translations();
      when(
        () => translations.translate(
          any(),
          fallback: any(named: 'fallback'),
        ),
      ).thenAnswer(
        (invocation) =>
            invocation.namedArguments[#fallback] as String? ??
            invocation.positionalArguments.first as String,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<TranslationsService>.value(
          value: translations,
          child: const MaterialApp(
            home: Scaffold(
              body: PhotoImportMobileSheet(eventId: 'event-1'),
            ),
          ),
        ),
      );

      expect(find.text('Galería'), findsOneWidget);
      expect(find.text('Archivos'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
