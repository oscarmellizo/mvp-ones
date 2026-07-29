import '../presentation/tutorial_keys.dart';
import 'tutorial_step.dart';

class TutorialSteps {
  static const String homeRoute = '/events';

  static final List<TutorialStep> all = [
    TutorialStep(
      id: 'home_help',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeHelpIcon,
      titleKey: 'Icono de ayuda',
      bodyKey: 'Toca aquí para iniciar esta guía cuando quieras.',
      shape: TutorialShape.circle,
    ),
    TutorialStep(
      id: 'home_search',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeSearch,
      titleKey: 'Buscar eventos',
      bodyKey: 'Escribe para encontrar rápidamente tus eventos.',
    ),
    TutorialStep(
      id: 'home_fab',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeFabCreate,
      titleKey: 'Crear evento',
      bodyKey: 'Toca aquí para crear tu primer evento.',
    ),
  ];
}
