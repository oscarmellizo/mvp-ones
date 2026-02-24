import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/http/ones_api_factory.dart';
import 'core/ui/splash_page.dart';
import 'features/auth/adapters/google/google_auth_repository.dart';
import 'features/auth/application/get_id_token_use_case.dart';
import 'features/auth/application/sign_in_with_google_use_case.dart';
import 'features/auth/application/sign_out_use_case.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/events/adapters/api/events_api_repository.dart';
import 'features/events/adapters/api/event_covers_api_repository.dart';
import 'features/events/adapters/api/event_cover_urls_api_repository.dart';
import 'features/events/adapters/api/events_metadata_api_repository.dart';
import 'features/events/application/create_event_use_case.dart';
import 'features/events/application/get_event_use_case.dart';
import 'features/events/application/list_events_use_case.dart';
import 'features/events/domain/events_repository.dart';
import 'features/events/presentation/events_controller.dart';
import 'features/events/presentation/event_covers_controller.dart';
import 'features/events/presentation/event_cover_urls_controller.dart';
import 'features/events/presentation/events_metadata_controller.dart';
import 'features/invitations/adapters/api/invitations_api_repository.dart';
import 'features/invitations/presentation/invitations_controller.dart';
import 'features/users/adapters/api/users_api_repository.dart';
import 'features/users/application/ensure_user_use_case.dart';
import 'features/events/presentation/pages/event_detail_page.dart';
import 'features/events/presentation/pages/home_shell_page.dart';
import 'features/events/presentation/pages/events_list_page.dart';
import 'features/events/presentation/pages/create_event_page.dart';
import 'features/auth/presentation/pages/login_page.dart';

class OnesApp extends StatelessWidget {
  const OnesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.fromDartDefines();

    final apiFactory = OnesApiFactory(config);

    final authRepository =
        GoogleAuthRepository(webClientId: config.googleWebClientId);

    final signInWithGoogle = SignInWithGoogleUseCase(authRepository);
    final signOut = SignOutUseCase(authRepository);
    final getIdToken = GetIdTokenUseCase(authRepository);

    final usersRepository = UsersApiRepository(apiFactory);
    final ensureUser = EnsureUserUseCase(usersRepository);
    final getPreferredName = GetPreferredNameUseCase(usersRepository);
    final updatePreferredName = UpdatePreferredNameUseCase(usersRepository);
    final lookupUserByEmail = LookupUserByEmailUseCase(usersRepository);

    final eventsRepository = EventsApiRepository(apiFactory);
    final listEvents = ListEventsUseCase(eventsRepository);
    final getEvent = GetEventUseCase(eventsRepository);
    final createEvent = CreateEventUseCase(eventsRepository);

    final eventsMetadataRepository = EventsMetadataApiRepository(apiFactory);
    final eventCoversRepository = EventCoversApiRepository(apiFactory);
    final eventCoverUrlsRepository = EventCoverUrlsApiRepository(apiFactory);
    final invitationsRepository = InvitationsApiRepository(apiFactory);

    return MultiProvider(
      providers: [
        Provider.value(value: config),
        Provider<EventsRepository>.value(value: eventsRepository),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            signInWithGoogle: signInWithGoogle,
            signOut: signOut,
            getIdToken: getIdToken,
            ensureUser: ensureUser,
            getPreferredName: getPreferredName,
            updatePreferredName: updatePreferredName,
            lookupUserByEmailUseCase: lookupUserByEmail,
          ),
        ),
        ChangeNotifierProxyProvider<AuthController, EventsController>(
          create: (_) => EventsController(
            listEvents: listEvents,
            getEvent: getEvent,
            createEvent: createEvent,
          ),
          update: (_, auth, events) {
            final controller = events ??
                EventsController(
                  listEvents: listEvents,
                  getEvent: getEvent,
                  createEvent: createEvent,
                );
            eventsRepository.setIdToken(auth.idToken);
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
      ],
      child: MaterialApp(
        title: 'Ones',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const _RootRouter(),
        routes: {
          EventsListPage.routeName: (_) => const EventsListPage(),
          CreateEventPage.routeName: (_) => const CreateEventPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == EventDetailPage.routeName) {
            final id = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) => EventDetailPage(eventId: id));
          }
          return null;
        },
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.isLoading && !auth.isSignedIn) {
      return const SplashPage();
    }

    if (!auth.isSignedIn) {
      return const LoginPage();
    }

    return const HomeShellPage();
  }
}
