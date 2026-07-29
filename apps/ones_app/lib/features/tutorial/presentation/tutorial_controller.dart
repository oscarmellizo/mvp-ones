import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../domain/tutorial_steps.dart';
import '../domain/tutorial_step.dart';
import 'tutorial_store.dart';

class TutorialController {
  static final TutorialController instance = TutorialController._internal();
  final TutorialStore _store = TutorialStore();

  TutorialController._internal();

  Future<void> start(BuildContext context) async {
    // Build targets only for widgets currently mounted in this route
    final steps = TutorialSteps.all
        .where((s) => s.targetKey().currentContext != null)
        .toList(growable: false);
    if (steps.isEmpty) return;

    final targets = <TargetFocus>[];
    for (final step in steps) {
      targets.add(
        TargetFocus(
          identify: step.id,
          keyTarget: step.targetKey(),
          shape: step.shape == TutorialShape.circle
              ? ShapeLightFocus.Circle
              : ShapeLightFocus.RRect,
          contents: [
            TargetContent(
              align: step.align ?? ContentAlign.bottom,
              builder: (ctx, controller) => _buildBubble(
                ctx,
                step.titleKey,
                step.bodyKey,
              ),
            ),
          ],
        ),
      );
    }

    final coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.6),
      textSkip: 'Saltar',
      pulseEnable: true,
      hideSkip: false,
      onFinish: () { _store.markSeen(); },
      onSkip: () { _store.markSeen(); return true; },
    );

    coachMark.show(context: context);
  }

  Widget _buildBubble(BuildContext context, String? title, String? body) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (title != null && title.isNotEmpty) const SizedBox(height: 8),
          if (body != null && body.isNotEmpty) Text(body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Siguiente',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
