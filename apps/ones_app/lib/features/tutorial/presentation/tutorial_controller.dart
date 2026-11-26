import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/translations_service.dart';
import '../domain/tutorial_steps.dart';
import '../domain/tutorial_step.dart';
import 'tutorial_store.dart';

class TutorialController {
  static final TutorialController instance = TutorialController._internal();
  final TutorialStore _store = TutorialStore();

  TutorialController._internal();

  Future<void> start(
    BuildContext context, {
    String? routeName,
    String? seenRouteName,
    List<String>? onlyStepIds,
  }) async {
    // Filtra por ruta actual (o explícita) y reintenta si aún no están montados
    final currentRoute = routeName ?? ModalRoute.of(context)?.settings.name;

    List<TutorialStep> visibleSteps() => TutorialSteps.all.where((s) {
          if (currentRoute != null && s.routeName != currentRoute) return false;
          if (onlyStepIds != null && onlyStepIds.isNotEmpty && !onlyStepIds.contains(s.id)) {
            return false;
          }
          return s.targetKey().currentContext != null;
        }).toList(growable: false);

    List<TutorialStep> steps = visibleSteps();
    // Reintenta hasta 6 veces en ~1.5s para esperar al montaje
    for (int i = 0; steps.isEmpty && i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      steps = visibleSteps();
    }
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
                controller,
              ),
            ),
          ],
        ),
      );
    }

    final coachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withValues(alpha: 0.6),
      textSkip: 'Saltar',
      pulseEnable: true,
      hideSkip: false,
      beforeFocus: (target) async {
        final key = target.keyTarget;
        final ctx = key?.currentContext;
        if (ctx != null) {
          try {
            await Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 350),
              alignment: 0.1,
              curve: Curves.easeInOut,
            );
            await Future<void>.delayed(const Duration(milliseconds: 50));
          } catch (_) {}
        }
      },
      onFinish: () { _store.markSeen(routeName: seenRouteName ?? currentRoute); },
      onSkip: () { _store.markSeen(routeName: seenRouteName ?? currentRoute); return true; },
    );

    if (!context.mounted) return;
    coachMark.show(context: context);
  }

  Widget _buildBubble(
    BuildContext context,
    String? title,
    String? body,
    TutorialCoachMarkController controller,
  ) {
    final theme = Theme.of(context);
    final translations = context.read<TranslationsService>();
    final resolvedTitle =
        title == null ? null : translations.translate(title, fallback: title);
    final resolvedBody =
        body == null ? null : translations.translate(body, fallback: body);
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
          if (resolvedTitle != null && resolvedTitle.isNotEmpty)
            Text(resolvedTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (resolvedTitle != null && resolvedTitle.isNotEmpty) const SizedBox(height: 8),
          if (resolvedBody != null && resolvedBody.isNotEmpty) Text(resolvedBody),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => controller.next(),
                child: const Text('Siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
