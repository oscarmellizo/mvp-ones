import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ones_app/features/events/presentation/widgets/event_detail_details_widgets.dart';

void main() {
  testWidgets('EventDetailSectionCard renders title and children',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventDetailSectionCard(
            title: 'My Section',
            children: [
              Text('Child A'),
              Text('Child B'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('My Section'), findsOneWidget);
    expect(find.text('Child A'), findsOneWidget);
    expect(find.text('Child B'), findsOneWidget);
  });

  testWidgets('ReadOnlyField shows dash when value is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadOnlyField(
            label: 'Label',
            value: '',
          ),
        ),
      ),
    );

    expect(find.text('Label'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });
}
