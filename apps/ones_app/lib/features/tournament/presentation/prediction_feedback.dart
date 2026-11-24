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
  });

  final PredictionFeedbackType type;
  final bool? homeScoreCorrect;
  final bool? awayScoreCorrect;

  // Mirrors the scoring tiers for per-match feedback; totals stay server-owned.
  factory PredictionFeedback.evaluate({
    required int? predictedHome,
    required int? predictedAway,
    required int? actualHome,
    required int? actualAway,
    required bool matchFinished,
    bool fixtureMatches = true,
  }) {
    if (predictedHome == null && predictedAway == null) {
      return const PredictionFeedback(PredictionFeedbackType.missing);
    }
    if (predictedHome == null || predictedAway == null) {
      return const PredictionFeedback(PredictionFeedbackType.incomplete);
    }
    if (!matchFinished || actualHome == null || actualAway == null) {
      return const PredictionFeedback(PredictionFeedbackType.waiting);
    }
    if (!fixtureMatches) {
      return const PredictionFeedback(PredictionFeedbackType.fixtureMismatch);
    }

    final homeCorrect = predictedHome == actualHome;
    final awayCorrect = predictedAway == actualAway;
    if (homeCorrect && awayCorrect) {
      return const PredictionFeedback(
        PredictionFeedbackType.exact,
        homeScoreCorrect: true,
        awayScoreCorrect: true,
      );
    }
    if (homeCorrect || awayCorrect) {
      return PredictionFeedback(
        PredictionFeedbackType.partialScore,
        homeScoreCorrect: homeCorrect,
        awayScoreCorrect: awayCorrect,
      );
    }
    if (_outcome(predictedHome, predictedAway) ==
        _outcome(actualHome, actualAway)) {
      return const PredictionFeedback(
        PredictionFeedbackType.correctOutcome,
        homeScoreCorrect: false,
        awayScoreCorrect: false,
      );
    }
    return const PredictionFeedback(
      PredictionFeedbackType.missed,
      homeScoreCorrect: false,
      awayScoreCorrect: false,
    );
  }

  static int _outcome(int home, int away) {
    if (home > away) return 1;
    if (home < away) return -1;
    return 0;
  }
}
