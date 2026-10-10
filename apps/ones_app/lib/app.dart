import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';

import 'core/http/account_block.dart';
import 'core/config/app_config.dart';
import 'core/http/ones_api_factory.dart';
import 'core/i18n/translations_service.dart';
import 'core/ui/ones_theme.dart';
import 'core/ui/splash_page.dart';
import 'features/auth/adapters/firebase/firebase_auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/admin/adapters/api/admin_api_repository.dart';
import 'features/admin/adapters/api/admin_admins_api_repository.dart';
import 'features/admin/adapters/api/admin_frames_api_repository.dart';
import 'features/admin/adapters/api/admin_event_templates_api_repository.dart';
import 'features/admin/application/get_admin_me_use_case.dart';
import 'features/admin/presentation/admin_admins_controller.dart';
import 'features/admin/presentation/admin_frames_controller.dart';
import 'features/admin/presentation/admin_event_templates_controller.dart';
import 'features/events/adapters/api/event_covers_api_repository.dart';
import 'features/events/adapters/api/event_cover_urls_api_repository.dart';
import 'features/events/adapters/api/event_templates_api_repository.dart';
import 'features/events/adapters/api/frames_api_repository.dart';
import 'features/events/adapters/api/events_api_repository.dart';
import 'features/events/adapters/api/events_metadata_api_repository.dart';
import 'features/events/application/create_event_use_case.dart';
import 'features/events/application/get_event_use_case.dart';
import 'features/events/application/list_events_use_case.dart';
import 'features/events/application/update_event_use_case.dart';
import 'features/events/domain/events_repository.dart';
import 'features/events/presentation/events_controller.dart';
import 'features/events/presentation/event_covers_controller.dart';
import 'features/events/presentation/event_cover_urls_controller.dart';
import 'features/events/presentation/events_metadata_controller.dart';
import 'features/events/presentation/discover_templates_controller.dart';
import 'features/invitations/adapters/api/invitations_api_repository.dart';
import 'features/invitations/presentation/invitations_controller.dart';
import 'features/photos/adapters/api/event_photos_api.dart';
import 'features/photos/adapters/local/photo_storage.dart';
import 'features/photos/adapters/local/photo_upload_db.dart';
import 'features/photos/presentation/photos_upload_controller.dart';
import 'features/photos/presentation/photos_ws_controller.dart';
import 'features/users/adapters/api/users_api_repository.dart';
import 'features/users/application/ensure_user_use_case.dart';
import 'features/account/presentation/account_controller.dart';
import 'features/subscriptions/adapters/api/subscriptions_api_repository.dart';
import 'features/subscriptions/domain/subscriptions_repository.dart';
import 'features/subscriptions/presentation/subscriptions_controller.dart';
import 'core/services/live_event_notification_service.dart';
import 'core/widgets/live_events_selector.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/auth_route.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/verify_email_page.dart';
import 'features/auth/presentation/pages/offline_page.dart';
import 'features/account/adapters/api/account_api_repository.dart';
import 'features/events/presentation/pages/event_detail_page.dart';
import 'features/events/presentation/pages/home_shell_page.dart';
import 'features/events/presentation/pages/events_list_page.dart';
import 'features/events/presentation/pages/create_event_page.dart';
import 'features/events/presentation/pages/photo_capture_page.dart';
import 'features/invitations/presentation/pages/invitation_link_page.dart';
import 'features/events/presentation/pages/event_invite_link_page.dart';
import 'features/subscriptions/presentation/pages/subscription_plans_page.dart';
import 'features/subscriptions/presentation/pages/plans_result_web_page.dart';

final GlobalKey<NavigatorState> onesNavigatorKey = GlobalKey<NavigatorState>();

String? eventIdForRoute(String name, Uri baseUri) {
  final route = Uri.tryParse(name);
  if (route?.path != EventDetailPage.routeName) return null;
  final routeEventId = route?.queryParameters['eventId'];
  if (routeEventId != null && routeEventId.isNotEmpty) return routeEventId;
  if (baseUri.path != EventDetailPage.routeName) return null;
  final baseEventId = baseUri.queryParameters['eventId'];
  return baseEventId != null && baseEventId.isNotEmpty ? baseEventId : null;
}

String? invitationRouteForLink(Uri? link, {bool allowDevHost = false}) {
  if (link == null ||
      link.scheme != 'https' ||
      (link.host != 'app.ones.events' &&
          !(allowDevHost && link.host == 'appdev.ones.events')) ||
      link.hasPort ||
      link.path != InvitationLinkPage.routeName) {
    return null;
  }
  final tokens = link.queryParametersAll['token'];
  final actions = link.queryParametersAll['action'];
  if (tokens == null || tokens.length != 1 || tokens.single.trim().isEmpty ||
      (actions != null && (actions.length != 1 ||
          !const {'accept', 'reject'}.contains(actions.single)))) {
    return null;
  }
  return Uri(
    path: InvitationLinkPage.routeName,
    queryParameters: {
      'token': tokens.single,
      if (actions != null) 'action': actions.single,
    },
  ).toString();
}

class OnesApp extends StatelessWidget {
  final AppConfig config;

  const OnesApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final apiFactory = OnesApiFactory(config);

    final authRepository =
        FirebaseAuthRepository(googleServerClientId: config.googleWebClientId);

    final usersRepository = UsersApiRepository(apiFactory);
    final accountRepository = AccountApiRepository(apiFactory);
    final ensureUser = EnsureUserUseCase(usersRepository);
    final getUserPreferences = GetUserPreferencesUseCase(usersRepository);
    final updateUserPreferences = UpdateUserPreferencesUseCase(usersRepository);
    final lookupUserByEmail = LookupUserByEmailUseCase(usersRepository);

    final adminRepository = AdminApiRepository(apiFactory);
    final getAdminMe = GetAdminMeUseCase(adminRepository);

    final adminAdminsRepository = AdminAdminsApiRepository(apiFactory);
    final adminFramesRepository = AdminFramesApiRepository(apiFactory);
    final adminEventTemplatesRepository =
        AdminEventTemplatesApiRepository(apiFactory);

    final eventsRepository = EventsApiRepository(apiFactory);
    final listEvents = ListEventsUseCase(eventsRepository);
    final getEvent = GetEventUseCase(eventsRepository);
    final createEvent = CreateEventUseCase(eventsRepository);
    final updateEvent = UpdateEventUseCase(eventsRepository);

    final eventsMetadataRepository = EventsMetadataApiRepository(apiFactory);
    final eventCoversRepository = EventCoversApiRepository(apiFactory);
    final eventCoverUrlsRepository = EventCoverUrlsApiRepository(apiFactory);
    final invitationsRepository = InvitationsApiRepository(apiFactory);

    final eventTemplatesRepository = EventTemplatesApiRepository(apiFactory);
    final framesRepository = FramesApiRepository(apiFactory);

    final eventPhotosApi = EventPhotosApi(apiFactory);
    final eventPhotosGalleryApi = EventPhotosApi(apiFactory);
    final subscriptionsRepository = SubscriptionsApiRepository(apiFactory);
    // NOTE: PhotosGalleryController is NOT registered here as a global singleton.
    // Each EventDetailPage creates its own instance to guarantee per-event isolation.
    final photoUploadDb = PhotoUploadDb();
    final photoStorage = PhotoStorage();
    final photosWsController =
        PhotosWsController(wsUrl: config.photosWsUrl ?? '');

    return MultiProvider(
      providers: [
        Provider.value(value: config),
        Provider.value(value: photoStorage),
        ChangeNotifierProvider(
          create: (_) {
            final ctrl = AuthController(
              authRepository: authRepository,
              ensureUser: ensureUser,
              getUserPreferences: getUserPreferences,
              updateUserPreferences: updateUserPreferences,
              lookupUserByEmailUseCase: lookupUserByEmail,
              getAdminMe: getAdminMe,
              reactivateAccount: (token) async => (await accountRepository.reactivate(token)) != null,
            );
            ctrl.restoreSessionIfPossible();
            return ctrl;
          },
        ),
        ProxyProvider<AuthController, EventsRepository>(
          update: (_, auth, __) {
            apiFactory.setTokenRefresher(auth.refreshIdToken);
            apiFactory.setAccountBlockedHandler(auth.signOutBecauseAccountBlocked);
            eventsRepository.setIdToken(auth.idToken);
            return eventsRepository;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, TranslationsService>(
          create: (_) {
            final translationsService =
                TranslationsService(apiFactory.create());
            // Initialize asynchronously
            translationsService.ensureInitialized();
            return translationsService;
          },
          update: (_, auth, translationsService) {
            translationsService ??= TranslationsService(apiFactory.create());
            translationsService.setAuthController(auth);
            final preferredLanguage =
                auth.isRegistered ? auth.languagePreference : null;
            if (!auth.isLoading &&
                preferredLanguage != null &&
                preferredLanguage.trim().isNotEmpty &&
                preferredLanguage.trim().toLowerCase() !=
                    translationsService.getCurrentLanguage()) {
              translationsService
                  .syncLanguageFromUserPreference(preferredLanguage);
            }
            return translationsService;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, AccountController>(
          create: (_) => AccountController(apiFactory: apiFactory),
          update: (_, auth, ctrl) {
            final controller = ctrl ?? AccountController(apiFactory: apiFactory);
            controller.setIdToken(auth.idToken);
            final token = auth.idToken;
            if (token != null && token.isNotEmpty) {
              controller.ensureReactivatedIfEligible(
                sessionKey: auth.user?.userId,
                onClosed: () => auth.signOutBecauseAccountBlocked(AccountBlock.closed),
              );
            }
            return controller;
          },
        ),
        ProxyProvider<AuthController, EventTemplatesApiRepository>(
          update: (_, auth, __) {
            eventTemplatesRepository.setIdToken(auth.idToken);
            return eventTemplatesRepository;
          },
        ),
        ProxyProvider<AuthController, FramesApiRepository>(
          update: (_, auth, __) {
            framesRepository.setIdToken(auth.idToken);
            return framesRepository;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, EventsController>(
          create: (_) => EventsController(
            listEvents: listEvents,
            getEvent: getEvent,
            createEvent: createEvent,
            updateEventUseCase: updateEvent,
            eventsRepository: eventsRepository,
          ),
          update: (_, auth, events) {
            apiFactory.setTokenRefresher(auth.refreshIdToken);
            final controller = events ??
                EventsController(
                  listEvents: listEvents,
                  getEvent: getEvent,
                  createEvent: createEvent,
                  updateEventUseCase: updateEvent,
                  eventsRepository: eventsRepository,
                );
            eventsRepository.setIdToken(auth.idToken);
            controller.setIdToken(auth.idToken, userId: auth.user?.userId);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController,
            DiscoverTemplatesController>(
          create: (_) => DiscoverTemplatesController(
            repository: eventTemplatesRepository,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                DiscoverTemplatesController(
                  repository: eventTemplatesRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, AdminAdminsController>(
          create: (_) => AdminAdminsController(
            repository: adminAdminsRepository,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                AdminAdminsController(
                  repository: adminAdminsRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, AdminFramesController>(
          create: (_) => AdminFramesController(
            repository: adminFramesRepository,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                AdminFramesController(
                  repository: adminFramesRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController,
            AdminEventTemplatesController>(
          create: (_) => AdminEventTemplatesController(
            repository: adminEventTemplatesRepository,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                AdminEventTemplatesController(
                  repository: adminEventTemplatesRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, EventsMetadataController>(
          create: (_) => EventsMetadataController(
            repository: eventsMetadataRepository,
          ),
          update: (_, auth, metadata) {
            final controller = metadata ??
                EventsMetadataController(
                  repository: eventsMetadataRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, EventCoversController>(
          create: (_) => EventCoversController(
            repository: eventCoversRepository,
          ),
          update: (_, auth, covers) {
            final controller = covers ??
                EventCoversController(
                  repository: eventCoversRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ProxyProvider<AuthController, EventCoversApiRepository>(
          update: (_, auth, __) {
            eventCoversRepository.setIdToken(auth.idToken);
            return eventCoversRepository;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, EventCoverUrlsController>(
          create: (_) => EventCoverUrlsController(
            repository: eventCoverUrlsRepository,
          ),
          update: (_, auth, coverUrls) {
            final controller = coverUrls ??
                EventCoverUrlsController(
                  repository: eventCoverUrlsRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, InvitationsController>(
          create: (_) => InvitationsController(
            repository: invitationsRepository,
          ),
          update: (_, auth, inv) {
            final controller = inv ??
                InvitationsController(
                  repository: invitationsRepository,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, PhotosUploadController>(
          create: (_) => PhotosUploadController(
            api: eventPhotosApi,
            db: photoUploadDb,
            storage: photoStorage,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                PhotosUploadController(
                  api: eventPhotosApi,
                  db: photoUploadDb,
                  storage: photoStorage,
                );
            controller.setIdToken(auth.idToken);
            return controller;
          },
        ),
        ProxyProvider<AuthController, EventPhotosApi>(
          update: (_, auth, __) {
            eventPhotosGalleryApi.setIdToken(auth.idToken);
            return eventPhotosGalleryApi;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, PhotosWsController>(
          create: (_) => photosWsController,
          update: (_, auth, ctrl) {
            final controller = ctrl ?? photosWsController;
            controller.setIdToken(auth.idToken);
            final token = auth.idToken;
            if (token != null && token.isNotEmpty) {
              controller.connect();
            } else {
              controller.disconnect();
            }
            return controller;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, SubscriptionsController>(
          create: (_) => SubscriptionsController(subscriptionsRepository),
          update: (_, auth, ctrl) {
            apiFactory.setTokenRefresher(auth.refreshIdToken);
            subscriptionsRepository.setIdToken(auth.idToken);
            final controller = ctrl ?? SubscriptionsController(subscriptionsRepository);
            return controller;
          },
        ),
      ],
      child: AppLinkHandler(
        child: Builder(
          builder: (context) {
            final lang = context.watch<TranslationsService>().getCurrentLanguage();
            return MaterialApp(
            title: 'Ones',
            theme: OnesTheme.light(),
            locale: Locale(lang),
            supportedLocales: const [
              Locale('es'),
              Locale('en'),
              Locale('pt'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            navigatorKey: onesNavigatorKey,
            home: const _RootRouter(),
            routes: {
              EventsListPage.routeName: (_) => const EventsListPage(),
              CreateEventPage.routeName: (_) => const CreateEventPage(),
            },
            onGenerateRoute: (settings) {
              final name = settings.name;
              if (name == null || name.isEmpty) return null;

              final uri = Uri.parse(name);
              if (uri.path == '/plans/success' || uri.path == '/plans/pending' || uri.path == '/plans/failure') {
                return MaterialPageRoute(
                  builder: (_) => PlansResultWebPage(result: uri.pathSegments.last),
                );
              }
              if (uri.path == SubscriptionPlansPage.routeName) {
                return MaterialPageRoute(builder: (_) => const SubscriptionPlansPage());
              }
              if (uri.path == InvitationLinkPage.routeName) {
                final token = uri.queryParameters['token'];
                if (token == null || token.trim().isEmpty) {
                  return null;
                }
                final action = uri.queryParameters['action'];
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => InvitationLinkPage(
                    token: token,
                    action: action,
                  ),
                );
              }
              if (uri.path == EventInviteLinkPage.routeName) {
                final eventId = uri.queryParameters['eventId'];
                final sig = uri.queryParameters['sig'];
                if (eventId == null || eventId.trim().isEmpty) {
                  return null;
                }
                if (sig == null || sig.trim().isEmpty) {
                  return null;
                }
                return MaterialPageRoute(
                  builder: (_) => EventInviteLinkPage(
                    eventId: eventId,
                    sig: sig,
                  ),
                );
              }
              if (uri.path == EventDetailPage.routeName) {
                final eventId = eventIdForRoute(name, Uri.base) ??
                    (settings.arguments as String?);
                if (eventId == null || eventId.isEmpty) {
                  return null;
                }

                final initialPhotoId = uri.queryParameters['photoId'];
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => EventDetailPage(
                    eventId: eventId,
                    initialPhotoId: initialPhotoId,
                  ),
                );
              }
              return null;
            },
            debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}

class AppLinkHandler extends StatefulWidget {
  final Widget child;
  final AppLinks? appLinks;

  const AppLinkHandler({super.key, required this.child, this.appLinks});

  @override
  State<AppLinkHandler> createState() => _AppLinkHandlerState();
}

class _AppLinkHandlerState extends State<AppLinkHandler> {
  late final AppLinks _appLinks = widget.appLinks ?? AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _pendingInvitationRoute;
  String? _lastOpenedRoute;
  DateTime? _lastOpenedAt;
  bool _openScheduled = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    unawaited(() async {
      try {
        _handleLink(await _appLinks.getInitialLink());
      } catch (_) {}
    }());
    _subscription = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (Object error) {
        if (kDebugMode) debugPrint('app links error: ${error.runtimeType}');
      },
    );
  }

  void _handleLink(Uri? link) {
    if (!mounted || link == null) return;
    final invitationRoute = invitationRouteForLink(
      link,
      allowDevHost: context.read<AppConfig>().env == 'dev',
    );
    if (invitationRoute != null) {
      final recentlyOpened = _lastOpenedRoute == invitationRoute &&
          _lastOpenedAt != null &&
          DateTime.now().difference(_lastOpenedAt!) < const Duration(seconds: 2);
      if (recentlyOpened || _pendingInvitationRoute == invitationRoute) return;
      setState(() => _pendingInvitationRoute = invitationRoute);
      return;
    }
    if ((link.scheme != 'ones' && link.scheme != 'onesdev') ||
        link.host != 'plans' ||
        link.pathSegments.length != 1 ||
        !const {'success', 'pending', 'failure'}
            .contains(link.pathSegments.first)) {
      return;
    }
    final result = link.pathSegments.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onesNavigatorKey.currentState?.pushNamed(
        SubscriptionPlansPage.routeName,
        arguments: result,
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registered = context.watch<AuthController>().isRegistered;
    if (registered && _pendingInvitationRoute != null && !_openScheduled) {
      _openScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openScheduled = false;
        if (!mounted || !context.read<AuthController>().isRegistered) return;
        final navigator = onesNavigatorKey.currentState;
        final route = _pendingInvitationRoute;
        if (navigator == null || route == null) return;
        _pendingInvitationRoute = null;
        _lastOpenedRoute = route;
        _lastOpenedAt = DateTime.now();
        navigator.pushNamed(route);
      });
    }
    return widget.child;
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingNotif());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNotif();
      // Volvió desde el correo (otra app o pestaña): si ya verificó, avanzamos sin pedirle nada.
      final auth = context.read<AuthController>();
      auth.refreshEmailVerification();
      // Si la sesión murió en segundo plano (cuenta borrada, sesión revocada), vuelve al login.
      auth.checkSessionOnResume();
    }
  }

  bool _permissionRequested = false;

  void _checkPendingNotif() {
    final pending = LiveEventNotificationService.consumePending();
    if (pending == null) return;
    if (!mounted) return;
    _handleNotifPayload(pending.payload, pending.actionId);
  }

  void _maybeRequestPermission() {
    if (_permissionRequested) return;
    _permissionRequested = true;
    LiveEventNotificationService().requestPermission();
  }

  void _handleNotifPayload(String? payload, String? actionId) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final isMulti = map['multi'] == true;

      if (isMulti || actionId == kActionSelect) {
        final events = context.read<EventsController>().events;
        final now = DateTime.now();
        final liveEvents = events.where((e) {
          final start = e.startAt.toLocal();
          final end = e.endAt.toLocal();
          return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
              now.isBefore(end);
        }).toList(growable: false);
        if (liveEvents.isEmpty) return;
        LiveEventsSelector.show(
          context: context,
          liveEvents: liveEvents,
          onSelect: (eventId, openCamera) =>
              _navigateToEvent(eventId, openCamera),
        );
        return;
      }

      final eventId = map['eventId'] as String?;
      if (eventId == null || eventId.isEmpty) return;
      final openCamera = actionId == kActionCamera;
      _navigateToEvent(eventId, openCamera);
    } catch (_) {}
  }

  void _navigateToEvent(String eventId, bool openCamera) {
    final nav = Navigator.of(context);
    nav.pushNamed(
      EventDetailPage.routeName,
      arguments: eventId,
    ).then((_) {
      if (openCamera && mounted) {
        final events = context.read<EventsController>().events;
        final event = events.where((e) => e.id == eventId).firstOrNull;
        if (event == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoCapturePage(
              eventId: eventId,
              frameIds: event.frameIds,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final base = Uri.base;
    if (base.path == EventInviteLinkPage.routeName) {
      final eventId = base.queryParameters['eventId'];
      final sig = base.queryParameters['sig'];
      if (eventId != null &&
          eventId.trim().isNotEmpty &&
          sig != null &&
          sig.trim().isNotEmpty) {
        return EventInviteLinkPage(eventId: eventId, sig: sig);
      }
    }
    if (auth.isRegistered && base.path == InvitationLinkPage.routeName) {
      final token = base.queryParameters['token'];
      if (token != null && token.trim().isNotEmpty) {
        final action = base.queryParameters['action'];
        return InvitationLinkPage(token: token, action: action);
      }
    }

    switch (resolveAuthRoute(auth)) {
      case AuthRoute.splash:
        return const SplashPage();
      case AuthRoute.offline:
        return const OfflinePage();
      case AuthRoute.verifyEmail:
        return const VerifyEmailPage();
      case AuthRoute.completeRegistration:
        return const RegisterPage(popToRootOnComplete: false);
      case AuthRoute.login:
        return const LoginPage();
      case AuthRoute.home:
        break;
    }

    _maybeRequestPermission();
    return const HomeShellPage();
  }
}
