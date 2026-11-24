import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/tournament/presentation/prediction_feedback.dart';

void main() {
  group('PredictionFeedback', () {
    test('keeps blank and incomplete forecasts distinct from a 0-0 score', () {
      final missing = PredictionFeedback.evaluate(
        predictedHome: null,
        predictedAway: null,
        actualHome: 0,
        actualAway: 0,
        matchFinished: true,
      );
      final incomplete = PredictionFeedback.evaluate(
        predictedHome: 0,
        predictedAway: null,
        actualHome: 0,
        actualAway: 0,
        matchFinished: true,
      );
      final explicitZero = PredictionFeedback.evaluate(
        predictedHome: 0,
        predictedAway: 0,
        actualHome: 0,
        actualAway: 0,
        matchFinished: true,
      );

      expect(missing.type, PredictionFeedbackType.missing);
      expect(incomplete.type, PredictionFeedbackType.incomplete);
      expect(explicitZero.type, PredictionFeedbackType.exact);
    });

    test('waits for the official result before showing accuracy', () {
      final feedback = PredictionFeedback.evaluate(
        predictedHome: 2,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 1,
        matchFinished: false,
      );

      expect(feedback.type, PredictionFeedbackType.waiting);
      expect(feedback.homeScoreCorrect, isNull);
      expect(feedback.awayScoreCorrect, isNull);
    });

    test('marks exact and partial score hits separately', () {
      final exact = PredictionFeedback.evaluate(
        predictedHome: 2,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 1,
        matchFinished: true,
      );
      final partial = PredictionFeedback.evaluate(
        predictedHome: 2,
        predictedAway: 0,
        actualHome: 2,
        actualAway: 1,
        matchFinished: true,
      );

      expect(exact.type, PredictionFeedbackType.exact);
      expect(partial.type, PredictionFeedbackType.partialScore);
      expect(partial.homeScoreCorrect, isTrue);
      expect(partial.awayScoreCorrect, isFalse);
    });

    test('identifies an away-goal partial hit independently', () {
      final partial = PredictionFeedback.evaluate(
        predictedHome: 0,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 1,
        matchFinished: true,
      );

      expect(partial.type, PredictionFeedbackType.partialScore);
      expect(partial.homeScoreCorrect, isFalse);
      expect(partial.awayScoreCorrect, isTrue);
    });

    test('recognizes a correct outcome even when both goals differ', () {
      final feedback = PredictionFeedback.evaluate(
        predictedHome: 3,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 0,
        matchFinished: true,
      );

      expect(feedback.type, PredictionFeedbackType.correctOutcome);
      expect(feedback.homeScoreCorrect, isFalse);
      expect(feedback.awayScoreCorrect, isFalse);
    });

    test('marks a wrong outcome and a mismatched knockout fixture', () {
      final missed = PredictionFeedback.evaluate(
        predictedHome: 0,
        predictedAway: 2,
        actualHome: 2,
        actualAway: 1,
        matchFinished: true,
      );
      final fixtureMismatch = PredictionFeedback.evaluate(
        predictedHome: 2,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 1,
        matchFinished: true,
        fixtureMatches: false,
      );

      expect(missed.type, PredictionFeedbackType.missed);
      expect(fixtureMismatch.type, PredictionFeedbackType.fixtureMismatch);
      expect(fixtureMismatch.homeScoreCorrect, isNull);
      expect(fixtureMismatch.awayScoreCorrect, isNull);
    });
  });
}
