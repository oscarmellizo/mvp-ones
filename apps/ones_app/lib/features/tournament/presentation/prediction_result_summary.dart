import 'package:flutter/material.dart';

import 'prediction_feedback.dart';

class PredictionResultSummary extends StatelessWidget {
  const PredictionResultSummary({
    super.key,
    required this.actualHomeName,
    required this.actualAwayName,
    required this.actualHomeGoals,
    required this.actualAwayGoals,
    required this.matchExists,
    required this.finished,
    required this.feedback,
    required this.predictedHomeName,
    required this.predictedAwayName,
    required this.compareFixture,
  });

  final String actualHomeName;
  final String actualAwayName;
  final int? actualHomeGoals;
  final int? actualAwayGoals;
  final bool matchExists;
  final bool finished;
  final PredictionFeedback feedback;
  final String predictedHomeName;
  final String predictedAwayName;
  final bool compareFixture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasScore = actualHomeGoals != null || actualAwayGoals != null;
    final isMismatch = compareFixture &&
        feedback.type == PredictionFeedbackType.fixtureMismatch;

    Color? explanationColor;
    String? explanation;
    IconData? explanationIcon;
    switch (feedback.type) {
      case PredictionFeedbackType.exact:
        explanationColor = Colors.green.shade700;
        explanation = 'Ambos marcadores coinciden.';
        explanationIcon = Icons.check_circle_rounded;
        break;
      case PredictionFeedbackType.partialScore:
        explanationColor = Colors.green.shade700;
        final correctSide = feedback.homeScoreCorrect == true
            ? predictedHomeName
            : predictedAwayName;
        explanation =
            'Acierto parcial: coincidieron los goles de $correctSide.';
        explanationIcon = Icons.check_circle_rounded;
        break;
      case PredictionFeedbackType.correctOutcome:
        explanationColor = colors.tertiary;
        explanation =
            'Acertaste quién ganó o el empate; los dos marcadores fueron distintos.';
        explanationIcon = Icons.thumb_up_alt_rounded;
        break;
      case PredictionFeedbackType.missed:
        explanationColor = colors.error;
        explanation = 'Ninguno de los dos marcadores coincide.';
        explanationIcon = Icons.cancel_rounded;
        break;
      case PredictionFeedbackType.fixtureMismatch:
        explanationColor = colors.onSurfaceVariant;
        explanation =
            'El partido real fue $actualHomeName vs. $actualAwayName; '
            'tu cruce era $predictedHomeName vs. $predictedAwayName. '
            'Por eso no se comparan los goles.';
        explanationIcon = Icons.info_outline_rounded;
        break;
      case PredictionFeedbackType.waiting:
      case PredictionFeedbackType.missing:
      case PredictionFeedbackType.incomplete:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  finished ? 'RESULTADO REAL' : 'MARCADOR REAL',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (hasScore && !finished)
                Text(
                  'EN CURSO',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          if (hasScore)
            Row(
              children: [
                Expanded(
                  child: Text(
                    actualHomeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${actualHomeGoals ?? '–'}  –  ${actualAwayGoals ?? '–'}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    actualAwayName,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
              ],
            )
          else
            Text(
              matchExists
                  ? 'Marcador pendiente de registrar.'
                  : 'Aún no hay partido o marcador real registrado.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          if (hasScore && !finished) ...[
            const SizedBox(height: 3),
            Text(
              'Este marcador aún no se evalúa hasta finalizar el partido.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
            ),
          ],
          if (isMismatch) ...[
            const SizedBox(height: 5),
            Text(
              explanation ??
                  'El resultado corresponde a un cruce distinto; los goles '
                      'quedan sin evaluar.',
              style: TextStyle(color: explanationColor, fontSize: 10),
            ),
          ] else if (explanation != null) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(explanationIcon, size: 14, color: explanationColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    explanation,
                    style: TextStyle(
                      color: explanationColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
