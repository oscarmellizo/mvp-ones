import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../presentation/tutorial_keys.dart';
import 'tutorial_step.dart';

class TutorialSteps {
  static const String homeRoute = '/events';
  static const String createRoute = '/events/create';
  static const String detailRoute = '/events/detail';

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
      id: 'home_bell',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeBellIcon,
      titleKey: 'Notificaciones',
      bodyKey: 'Aquí verás invitaciones y avisos importantes.',
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
      id: 'home_today',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeHeaderToday,
      titleKey: 'Eventos de hoy',
      bodyKey: 'Aquí se muestran los eventos que están ocurriendo hoy.',
    ),
    TutorialStep(
      id: 'home_next',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeHeaderNext,
      titleKey: 'Próximos eventos',
      bodyKey: 'Aquí verás los eventos que vienen en los próximos días.',
    ),
    TutorialStep(
      id: 'home_fab',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeFabCreate,
      titleKey: 'Crear evento',
      bodyKey: 'Toca aquí para crear tu primer evento.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'home_tab_home',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeTabHome,
      titleKey: 'Inicio',
      bodyKey: 'Regresa al inicio desde cualquier parte.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'home_tab_galleries',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeTabGalleries,
      titleKey: 'Galerías',
      bodyKey: 'Explora tus fotos y videos por evento.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'home_tab_profile',
      routeName: homeRoute,
      targetKey: () => TutorialKeys.homeTabProfile,
      titleKey: 'Perfil',
      bodyKey: 'Ajusta tu cuenta y preferencias.',
      align: ContentAlign.top,
    ),
    // Create Event
    TutorialStep(
      id: 'create_help',
      routeName: createRoute,
      targetKey: () => TutorialKeys.createHelpIcon,
      titleKey: 'Ayuda',
      bodyKey: 'Inicia o repite la guía de esta pantalla.',
      shape: TutorialShape.circle,
    ),
    TutorialStep(
      id: 'create_title',
      routeName: createRoute,
      targetKey: () => TutorialKeys.createTitleField,
      titleKey: 'Nombre del evento',
      bodyKey: 'Escribe un nombre claro para tu evento.',
    ),
    TutorialStep(
      id: 'create_when',
      routeName: createRoute,
      targetKey: () => TutorialKeys.createWhenCard,
      titleKey: 'Cuándo',
      bodyKey: 'Selecciona fecha y hora de inicio y fin.',
    ),
    TutorialStep(
      id: 'create_cta',
      routeName: createRoute,
      targetKey: () => TutorialKeys.createCtaCreate,
      titleKey: 'Crear',
      bodyKey: 'Toca para crear tu evento cuando todo esté listo.',
      align: ContentAlign.top,
    ),
    // Event Detail
    TutorialStep(
      id: 'event_help',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventHelpIcon,
      titleKey: 'Ayuda',
      bodyKey: 'Inicia o repite la guía de esta pantalla.',
      shape: TutorialShape.circle,
    ),
    TutorialStep(
      id: 'event_tab_gallery',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventTabGallery,
      titleKey: 'Galería',
      bodyKey: 'Mira y comparte las fotos del evento.',
    ),
    // Event detail - gallery filters
    TutorialStep(
      id: 'event_filter_all',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventFilterAll,
      titleKey: 'Todas las fotos',
      bodyKey: 'Muestra todas las fotos del evento sin filtrar.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'event_filter_shared',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventFilterShared,
      titleKey: 'Compartidas por mí',
      bodyKey: 'Filtra para ver sólo las fotos que tú compartiste.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'event_filter_mine',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventFilterMine,
      titleKey: 'Mis fotos',
      bodyKey: 'Muestra únicamente tus fotos subidas al evento.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'event_filter_guests',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventFilterGuests,
      titleKey: 'Seleccionar invitados',
      bodyKey: 'Elige uno o varios invitados para ver sólo sus fotos.',
      align: ContentAlign.top,
    ),
    TutorialStep(
      id: 'event_tab_details',
      routeName: detailRoute,
      targetKey: () => TutorialKeys.eventTabDetails,
      titleKey: 'Detalles',
      bodyKey: 'Consulta información, invitados y QR.',
    ),
  ];
}
