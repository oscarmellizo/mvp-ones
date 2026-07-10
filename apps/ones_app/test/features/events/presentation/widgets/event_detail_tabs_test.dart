import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_api_client/ones_api_client.dart';
import 'package:provider/provider.dart';

import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/presentation/widgets/event_detail_tabs.dart';

class _FakeTranslationsService extends TranslationsService {
  _FakeTranslationsService()
      : super(OnesApiClient(basePathOverride: 'http://localhost:0'));

  @override
  String translate(String key, {String? fallback}) {
    return fallback ?? key;
  }
}

void main() {
  testWidgets('EventDetailTabs renders and triggers onChanged',
      (WidgetTester tester) async {
    int? changedTo;

    await tester.pumpWidget(
      ChangeNotifierProvider<TranslationsService>.value(
        value: _FakeTranslationsService(),
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailTabs(
              index: 0,
              onChanged: (i) {
                changedTo = i;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pump();

    expect(changedTo, 1);
  });
}
