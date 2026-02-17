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
import 'features/events/application/create_event_use_case.dart';
import 'features/events/application/get_event_use_case.dart';
import 'features/events/application/list_events_use_case.dart';
import 'features/events/presentation/events_controller.dart';
import 'features/events/presentation/pages/event_detail_page.dart';
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

    final eventsRepository = EventsApiRepository(apiFactory);
    final listEvents = ListEventsUseCase(eventsRepository);
    final getEvent = GetEventUseCase(eventsRepository);
    final createEvent = CreateEventUseCase(eventsRepository);

    return MultiProvider(
      providers: [
        Provider.value(value: config),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            signInWithGoogle: signInWithGoogle,
            signOut: signOut,
            getIdToken: getIdToken,
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

    if (auth.isLoading) {
      return const SplashPage();
    }

    if (!auth.isSignedIn) {
      return const LoginPage();
    }

    return const EventsListPage();
  }
}
