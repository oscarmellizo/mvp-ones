enum PredictionFeedbackType {
  waiting,
  missing,
  incomplete,
  exact,
  partialScore,
  correctOutcome,
  missed,
  fixtureMismatch,
}

class PredictionFeedback {
  const PredictionFeedback(
    this.type, {
    this.homeScoreCorrect,
    this.awayScoreCorrect,
    this.pointsAwarded,
  });

  final PredictionFeedbackType type;
  final bool? homeScoreCorrect;
  final bool? awayScoreCorrect;
  final int? pointsAwarded;

  // Per-match detail mirrors the server tiers; leaderboard totals stay server-owned.
  factory PredictionFeedback.evaluate({
    required int? predictedHome,
    required int? predictedAway,
    required int? actualHome,
    required int? actualAway,
    required bool matchFinished,
    bool fixtureMatches = true,
  }) {
    final resultAvailable =
        matchFinished && actualHome != null && actualAway != null;
    if (resultAvailable && !fixtureMatches) {
      return const PredictionFeedback(PredictionFeedbackType.fixtureMismatch);
    }
    if (predictedHome == null && predictedAway == null) {
      return PredictionFeedback(
        PredictionFeedbackType.missing,
        pointsAwarded: resultAvailable ? 0 : null,
      );
    }
    if (predictedHome == null || predictedAway == null) {
      return PredictionFeedback(
        PredictionFeedbackType.incomplete,
        pointsAwarded: resultAvailable ? 0 : null,
      );
    }
    if (!matchFinished || actualHome == null || actualAway == null) {
      return const PredictionFeedback(PredictionFeedbackType.waiting);
    }

    final homeCorrect = predictedHome == actualHome;
    final awayCorrect = predictedAway == actualAway;
    if (homeCorrect && awayCorrect) {
      return const PredictionFeedback(
        PredictionFeedbackType.exact,
        homeScoreCorrect: true,
        awayScoreCorrect: true,
        pointsAwarded: 10,
      );
    }
    if (homeCorrect || awayCorrect) {
      return PredictionFeedback(
        PredictionFeedbackType.partialScore,
        homeScoreCorrect: homeCorrect,
        awayScoreCorrect: awayCorrect,
        pointsAwarded: 5,
      );
    }
    if (_outcome(predictedHome, predictedAway) ==
        _outcome(actualHome, actualAway)) {
      return const PredictionFeedback(
        PredictionFeedbackType.correctOutcome,
        homeScoreCorrect: false,
        awayScoreCorrect: false,
        pointsAwarded: 0,
      );
    }
    return const PredictionFeedback(
      PredictionFeedbackType.missed,
      homeScoreCorrect: false,
      awayScoreCorrect: false,
      pointsAwarded: 0,
    );
  }

  static int _outcome(int home, int away) {
    if (home > away) return 1;
    if (home < away) return -1;
    return 0;
  }
}
