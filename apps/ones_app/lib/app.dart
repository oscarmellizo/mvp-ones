import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/http/ones_api_factory.dart';
import 'core/i18n/translations_service.dart';
import 'core/ui/ones_theme.dart';
import 'core/ui/splash_page.dart';
import 'features/auth/adapters/google/google_auth_repository.dart';
import 'features/auth/application/get_id_token_use_case.dart';
import 'features/auth/application/sign_in_with_google_use_case.dart';
import 'features/auth/application/sign_out_use_case.dart';
import 'features/auth/infrastructure/google_token_refresh_service.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/admin/adapters/api/admin_api_repository.dart';
import 'features/admin/adapters/api/admin_admins_api_repository.dart';
import 'features/admin/adapters/api/admin_frames_api_repository.dart';
import 'features/admin/adapters/api/admin_event_templates_api_repository.dart';
import 'features/admin/application/get_admin_me_use_case.dart';
import 'features/admin/presentation/admin_admins_controller.dart';
import 'features/admin/presentation/admin_frames_controller.dart';
import 'features/admin/presentation/admin_event_templates_controller.dart';
import 'features/admin/adapters/api/admin_ops_api_repository.dart';
import 'features/admin/presentation/admin_ops_controller.dart';
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
import 'features/subscriptions/adapters/api/subscriptions_api_repository.dart';
import 'features/subscriptions/domain/subscriptions_repository.dart';
import 'features/subscriptions/presentation/subscriptions_controller.dart';
import 'core/services/live_event_notification_service.dart';
import 'core/widgets/live_events_selector.dart';
import 'features/auth/presentation/pages/login_page.dart';
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

class OnesApp extends StatelessWidget {
  final AppConfig config;

  const OnesApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final apiFactory = OnesApiFactory(config);

    final authRepository =
        GoogleAuthRepository(webClientId: config.googleWebClientId);

    final tokenRefreshService = GoogleTokenRefreshService(
      webClientId: config.googleWebClientId,
    );

    final signInWithGoogle = SignInWithGoogleUseCase(authRepository);
    final signOut = SignOutUseCase(authRepository);
    final getIdToken = GetIdTokenUseCase(authRepository);

    final usersRepository = UsersApiRepository(apiFactory);
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
    final adminOpsRepository = AdminOpsApiRepository(apiFactory);

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
              signInWithGoogle: signInWithGoogle,
              signOut: signOut,
              getIdToken: getIdToken,
              ensureUser: ensureUser,
              getUserPreferences: getUserPreferences,
              updateUserPreferences: updateUserPreferences,
              lookupUserByEmailUseCase: lookupUserByEmail,
              getAdminMe: getAdminMe,
              tokenRefreshService: tokenRefreshService,
            );
            ctrl.restoreSessionIfPossible();
            return ctrl;
          },
        ),
        ProxyProvider<AuthController, EventsRepository>(
          update: (_, auth, __) {
            apiFactory.setTokenRefresher(auth.refreshIdToken);
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
            controller.setIdToken(auth.idToken);
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
        ChangeNotifierProxyProvider<AuthController, AdminOpsController>(
          create: (_) => AdminOpsController(
            repository: adminOpsRepository,
          ),
          update: (_, auth, ctrl) {
            final controller = ctrl ??
                AdminOpsController(
                  repository: adminOpsRepository,
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
                final eventId = uri.queryParameters['eventId'] ??
                    (settings.arguments as String?);
                if (eventId == null || eventId.isEmpty) {
                  return null;
                }

                final initialPhotoId = uri.queryParameters['photoId'];
                return MaterialPageRoute(
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
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks.getInitialLink().then(_handlePaymentLink);
    _appLinks.uriLinkStream.listen(_handlePaymentLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingNotif());
  }

  void _handlePaymentLink(Uri? uri) {
    if (uri == null ||
        (uri.scheme != 'ones' && uri.scheme != 'onesdev') ||
        uri.host != 'plans' ||
        uri.pathSegments.length != 1 ||
        !const {'success', 'pending', 'failure'}.contains(uri.pathSegments.first)) {
      return;
    }
    final result = uri.pathSegments.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onesNavigatorKey.currentState?.pushNamed(
        SubscriptionPlansPage.routeName,
        arguments: result,
      );
    });
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

    if (auth.isLoading && !auth.isSignedIn) {
      return const SplashPage();
    }

    if (!auth.isRegistered) {
      return const LoginPage();
    }

    _maybeRequestPermission();
    return const HomeShellPage();
  }
}
