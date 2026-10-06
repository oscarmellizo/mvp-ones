import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;
import 'package:ones_app/app.dart';
import 'package:ones_app/core/config/app_config.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/events/application/get_event_use_case.dart';
import 'package:ones_app/features/events/presentation/event_cover_urls_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/invitations/adapters/api/invitations_api_repository.dart';
import 'package:ones_app/features/invitations/presentation/invitations_controller.dart';
import 'package:ones_app/features/invitations/presentation/pages/invitation_link_page.dart';
import 'package:provider/provider.dart';

class _Invitation extends Mock implements api.Invitation {}
class _Repository extends Mock implements InvitationsApiRepository {}
class _Invitations extends Mock implements InvitationsController {}
class _Events extends Mock implements EventsController {}
class _GetEvent extends Mock implements GetEventUseCase {}
class _CoverUrls extends Mock implements EventCoverUrlsController {}
class _AppLinks extends Mock implements AppLinks {}

class _Auth extends ChangeNotifier implements AuthController {
  bool registered = false;

  @override
  bool get isRegistered => registered;

  void finishLogin() {
    registered = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('enlace móvil permitido conserva token y acción sin añadir el host', () {
    expect(
      invitationRouteForLink(Uri.parse(
        'https://app.ones.events/invitation?token=test-token&action=accept',
      )),
      '/invitation?token=test-token&action=accept',
    );
    expect(
      invitationRouteForLink(Uri.parse(
        'https://app.ones.events/invitation?token=test-token',
      )),
      '/invitation?token=test-token',
    );
    final dev = Uri.parse('https://appdev.ones.events/invitation?token=dev');
    expect(invitationRouteForLink(dev), isNull);
    expect(invitationRouteForLink(dev, allowDevHost: true),
        '/invitation?token=dev');
  });

  test('enlaces ajenos, duplicados o con acción inválida son ignorados', () {
    for (final url in [
      'http://app.ones.events/invitation?token=test-token',
      'https://attacker.invalid/invitation?token=test-token',
      'https://app.ones.events/invitation/extra?token=test-token',
      'https://app.ones.events/invitation?token=',
      'https://app.ones.events/invitation?token=a&token=b',
      'https://app.ones.events/invitation?token=a&action=other',
    ]) {
      expect(invitationRouteForLink(Uri.parse(url)), isNull);
    }
  });

  testWidgets('enlace inicial espera login y no duplica el mismo enlace del stream',
      (tester) async {
    final auth = _Auth();
    final appLinks = _AppLinks();
    final stream = StreamController<Uri>.broadcast();
    addTearDown(stream.close);
    final invitation = Uri.parse(
      'https://app.ones.events/invitation?token=test-token',
    );
    when(() => appLinks.getInitialLink()).thenAnswer((_) async => invitation);
    when(() => appLinks.uriLinkStream).thenAnswer((_) => stream.stream);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<AppConfig>.value(value: const AppConfig(
          env: 'prod', apiBaseUrl: '', googleWebClientId: null,
          photosWsUrl: null,
        )),
      ],
      child: AppLinkHandler(
        appLinks: appLinks,
        child: MaterialApp(
          navigatorKey: onesNavigatorKey,
          home: const Scaffold(body: Text('Inicio')),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text(settings.name!)),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Inicio'), findsOneWidget);
    auth.finishLogin();
    await tester.pumpAndSettle();
    expect(find.text('/invitation?token=test-token'), findsOneWidget);

    stream.add(invitation);
    await tester.pumpAndSettle();
    onesNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);

    onesNavigatorKey.currentState!.pushNamedAndRemoveUntil(
      '/events/detail?eventId=event-1', (_) => false,
    );
    await tester.pumpAndSettle();
    stream.add(Uri.parse('ones://plans/success'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('/subscription-plans'), findsOneWidget);
    stream.add(Uri.parse(
      'https://app.ones.events/invitation?token=second-token',
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('/invitation?token=second-token'), findsOneWidget);
  });

  late _Repository repository;
  late _Invitations invitations;
  late _Invitation invitation;
  late _Events events;
  late _CoverUrls coverUrls;

  setUp(() {
    repository = _Repository();
    invitations = _Invitations();
    invitation = _Invitation();
    events = _Events();
    coverUrls = _CoverUrls();
    when(() => invitations.repository).thenReturn(repository);
    when(() => repository.resolve('test-token'))
        .thenAnswer((_) async => invitation);
    when(() => invitation.eventId).thenReturn('event-1');
    when(() => invitation.eventTitle).thenReturn('Evento de prueba');
    when(() => invitation.eventStartAt).thenReturn(DateTime.utc(2026, 10, 5));
    when(() => invitation.eventEndAt).thenReturn(DateTime.utc(2026, 10, 6));
    when(() => invitation.eventLocation).thenReturn(null);
    when(() => invitations.accept('event-1')).thenAnswer((_) async {});
    final getEvent = _GetEvent();
    when(() => events.getEvent).thenReturn(getEvent);
    when(() => getEvent.execute('event-1'))
        .thenThrow(StateError('no details in test'));
  });

  Future<void> openInvitation(WidgetTester tester, {String? action}) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<InvitationsController>.value(value: invitations),
        ChangeNotifierProvider<EventsController>.value(value: events),
        ChangeNotifierProvider<EventCoverUrlsController>.value(value: coverUrls),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Inicio')),
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name!);
          if (uri.path == InvitationLinkPage.routeName) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => InvitationLinkPage(
                token: uri.queryParameters['token']!,
                action: uri.queryParameters['action'],
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Scaffold(
              body: Center(
                child: Text('Evento abierto: ${ModalRoute.of(context)!.settings.name}'),
              ),
            ),
          );
        },
      ),
    ));
    navigatorKey.currentState!.pushNamed(
      '/invitation?token=test-token${action == null ? '' : '&action=$action'}',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('aceptación directa reemplaza el enlace sin dejarlo en el historial',
      (tester) async {
    await openInvitation(tester, action: 'accept');

    expect(find.textContaining('Evento abierto: /events/detail?eventId=event-1'),
        findsOneWidget);
    final context = tester.element(find.textContaining('Evento abierto:'));
    expect(Navigator.of(context).canPop(), isFalse);
    verify(() => repository.resolve('test-token')).called(1);
    verify(() => invitations.accept('event-1')).called(1);
  });

  testWidgets('aceptación desde diálogo reemplaza el enlace', (tester) async {
    await openInvitation(tester);
    expect(find.text('Evento de prueba'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Evento abierto: /events/detail?eventId=event-1'),
        findsOneWidget);
    final context = tester.element(find.textContaining('Evento abierto:'));
    expect(Navigator.of(context).canPop(), isFalse);
    verify(() => repository.resolve('test-token')).called(1);
    verify(() => invitations.accept('event-1')).called(1);
  });

  testWidgets('enlace no disponible no muestra errores internos', (tester) async {
    when(() => repository.resolve('test-token')).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/v1/invitations/resolve'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/v1/invitations/resolve'),
        statusCode: 400,
      ),
    ));
    await openInvitation(tester);

    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('enlace de invitación'), findsOneWidget);
    await tester.tap(find.text('Ir al inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.byType(InvitationLinkPage), findsNothing);
    verify(() => repository.resolve('test-token')).called(1);
  });
}
