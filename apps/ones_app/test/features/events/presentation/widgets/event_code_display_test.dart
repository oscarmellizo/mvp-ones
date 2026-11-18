import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/presentation/widgets/event_detail_details_widgets.dart';

void main() {
  testWidgets('shows the generated event code in the detail field',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventCodeDisplay(
            label: 'Event code',
            code: '123456',
            unavailableText: 'Unavailable',
          ),
        ),
      ),
    );

    expect(find.text('Event code'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('shows a fallback if an older event has no code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventCodeDisplay(
            label: 'Event code',
            code: '',
            unavailableText: 'Unavailable',
          ),
        ),
      ),
    );

    expect(find.text('Unavailable'), findsOneWidget);
  });
}
