import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ones_app/features/events/presentation/widgets/create_event_datetime_widgets.dart';

void main() {
  testWidgets('CreateEventDateTimeCard renders placeholders when null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    );

    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Ends'), findsOneWidget);

    expect(find.text('mm/dd/yyyy'), findsNWidgets(2));
    expect(find.text('--:--'), findsNWidgets(2));
  });

  testWidgets('CreateEventDateTimeCard shows errorText when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    );

    expect(find.text('Invalid end date'), findsOneWidget);
  });
}
