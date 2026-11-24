import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/tournament/presentation/prediction_feedback.dart';
import 'package:ones_app/features/tournament/presentation/prediction_result_summary.dart';

void main() {
  testWidgets('shows the real score and names the side hit by a partial score',
      (tester) async {
    final feedback = PredictionFeedback.evaluate(
      predictedHome: 2,
      predictedAway: 0,
      actualHome: 2,
      actualAway: 1,
      matchFinished: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionResultSummary(
            actualHomeName: 'Equipo local',
            actualAwayName: 'Equipo visitante',
            actualHomeGoals: 2,
            actualAwayGoals: 1,
            matchExists: true,
            finished: true,
            feedback: feedback,
            predictedHomeName: 'Equipo local',
            predictedAwayName: 'Equipo visitante',
            compareFixture: false,
          ),
        ),
      ),
    );

    expect(find.text('RESULTADO REAL'), findsOneWidget);
    expect(find.text('Equipo local'), findsOneWidget);
    expect(find.text('Equipo visitante'), findsOneWidget);
    expect(find.text('2  –  1'), findsOneWidget);
    expect(
      find.text('Acierto parcial: coincidieron los goles de Equipo local.'),
      findsOneWidget,
    );
  });

  testWidgets('explains when a knockout result belongs to another fixture',
      (tester) async {
    final feedback = PredictionFeedback.evaluate(
      predictedHome: 1,
      predictedAway: 0,
      actualHome: 1,
      actualAway: 0,
      matchFinished: true,
      fixtureMatches: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PredictionResultSummary(
            actualHomeName: 'Equipo C',
            actualAwayName: 'Equipo D',
            actualHomeGoals: 1,
            actualAwayGoals: 0,
            matchExists: true,
            finished: true,
            feedback: feedback,
            predictedHomeName: 'Equipo A',
            predictedAwayName: 'Equipo B',
            compareFixture: true,
          ),
        ),
      ),
    );

    expect(find.text('RESULTADO REAL'), findsOneWidget);
    expect(find.text('1  –  0'), findsOneWidget);
    expect(
      find.textContaining('El partido real fue Equipo C vs. Equipo D'),
      findsOneWidget,
    );
    expect(find.textContaining('no se comparan los goles'), findsOneWidget);
  });
}
