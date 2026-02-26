import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ones_app/features/events/presentation/widgets/event_detail_tabs.dart';

void main() {
  testWidgets('EventDetailTabs renders and triggers onChanged',
      (WidgetTester tester) async {
    int? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventDetailTabs(
            index: 0,
            onChanged: (i) {
              changedTo = i;
            },
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
