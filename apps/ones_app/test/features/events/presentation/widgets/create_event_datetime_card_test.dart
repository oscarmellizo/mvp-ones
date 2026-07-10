import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_api_client/ones_api_client.dart';
import 'package:provider/provider.dart';

import 'package:ones_app/features/events/presentation/widgets/create_event_datetime_widgets.dart';
import 'package:ones_app/core/i18n/translations_service.dart';

class _FakeTranslationsService extends TranslationsService {
  _FakeTranslationsService()
      : super(OnesApiClient(basePathOverride: 'http://localhost:0'));

  @override
  String translate(String key, {String? fallback}) {
    return switch (key) {
      'create_event.starts' => 'Starts',
      'create_event.ends' => 'Ends',
      'create_event.placeholder_time' => '--:--',
      _ => fallback ?? key,
    };
  }
}

void main() {
  testWidgets('CreateEventDateTimeCard renders placeholders when null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TranslationsService>.value(
        value: _FakeTranslationsService(),
        child: MaterialApp(
          home: Scaffold(
            body: CreateEventDateTimeCard(
              startDate: null,
              startTime: null,
              endDate: null,
              endTime: null,
              errorText: null,
              onPickStartDate: () {},
              onPickStartTime: () {},
              onPickEndDate: () {},
              onPickEndTime: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Ends'), findsOneWidget);

    expect(find.text('dd/mm/aaaa'), findsNWidgets(2));
    expect(find.text('--:--'), findsNWidgets(2));
  });

  testWidgets('CreateEventDateTimeCard shows errorText when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TranslationsService>.value(
        value: _FakeTranslationsService(),
        child: MaterialApp(
          home: Scaffold(
            body: CreateEventDateTimeCard(
              startDate: null,
              startTime: null,
              endDate: null,
              endTime: null,
              errorText: 'Invalid end date',
              onPickStartDate: () {},
              onPickStartTime: () {},
              onPickEndDate: () {},
              onPickEndTime: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invalid end date'), findsOneWidget);
  });
}
