import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/tournament/presentation/prediction_score_field.dart';

void main() {
  testWidgets(
    'keeps correct and incorrect colors visible after predictions close',
    (tester) async {
      final homeController = TextEditingController(text: '2');
      final awayController = TextEditingController(text: '0');
      addTearDown(homeController.dispose);
      addTearDown(awayController.dispose);

      final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: Scaffold(
            body: Row(
              children: [
                PredictionScoreField(
                  controller: homeController,
                  enabled: false,
                  scoreCorrect: true,
                ),
                PredictionScoreField(
                  controller: awayController,
                  enabled: false,
                  scoreCorrect: false,
                ),
              ],
            ),
          ),
        ),
      );

      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      expect(fields[0].readOnly, isTrue);
      expect(fields[0].style?.color, Colors.green.shade700);
      expect(
        (fields[0].decoration!.enabledBorder as OutlineInputBorder)
            .borderSide
            .color,
        Colors.green.shade700,
      );
      expect(fields[1].style?.color, colorScheme.error);
      expect(
        (fields[1].decoration!.enabledBorder as OutlineInputBorder)
            .borderSide
            .color,
        colorScheme.error,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    },
  );
}
