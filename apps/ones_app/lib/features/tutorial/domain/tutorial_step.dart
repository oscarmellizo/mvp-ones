import 'package:flutter/widgets.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

enum TutorialShape { circle, roundedRect }

typedef KeyProvider = GlobalKey Function();

class TutorialStep {
  final String id;
  final String routeName;
  final KeyProvider targetKey;
  final String titleKey;
  final String bodyKey;
  final TutorialShape shape;
  final ContentAlign? align;
  final String? nextRoute;

  const TutorialStep({
    required this.id,
    required this.routeName,
    required this.targetKey,
    required this.titleKey,
    required this.bodyKey,
    this.shape = TutorialShape.roundedRect,
    this.align,
    this.nextRoute,
  });
}
