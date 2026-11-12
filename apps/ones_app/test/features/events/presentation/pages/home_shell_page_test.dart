import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/presentation/event_cover_urls_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/create_event_page.dart';
import 'package:ones_app/features/events/presentation/pages/home_shell_page.dart';
import 'package:ones_app/features/invitations/presentation/invitations_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Events extends Mock implements EventsController {}

class _Invitations extends Mock implements InvitationsController {}

class _CoverUrls extends Mock implements EventCoverUrlsController {}

class _Translations extends Mock implements TranslationsService {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ones.tutorial_seen./events': true,
      'ones.tutorial_version./events': 1,
    });
  });

  testWidgets('el botón + despliega y permite cerrar las acciones',
      (tester) async {
    await _pumpHomeShellPage(tester);

    expect(find.text('home.action_create_event'), findsNothing);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('home.action_create_event'), findsOneWidget);
    expect(find.text('home.action_scan_event_qr'), findsOneWidget);
    expect(find.text('home.action_enter_event_code'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('home.action_create_event'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('tocar fuera del menú lo cierra', (tester) async {
    await _pumpHomeShellPage(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 40));
    await tester.pumpAndSettle();

    expect(find.text('home.action_create_event'), findsNothing);
  });

  testWidgets('las acciones caben en una pantalla estrecha', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHomeShellPage(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('home.action_enter_event_code'), findsOneWidget);
  });

  testWidgets('seleccionar crear evento navega al destino existente',
      (tester) async {
    await _pumpHomeShellPage(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('home.action_create_event'));
    await tester.pumpAndSettle();

    expect(find.text('create event destination'), findsOneWidget);
  });
}

Future<void> _pumpHomeShellPage(WidgetTester tester) async {
  final events = _Events();
  final invitations = _Invitations();
  final translations = _Translations();
  when(() => events.events).thenReturn([]);
  when(() => events.loading).thenReturn(false);
  when(() => events.error).thenReturn(null);
  when(() => events.refresh()).thenAnswer((_) async {});
  when(() => invitations.unreadCount).thenReturn(0);
  when(() => invitations.refresh()).thenAnswer((_) async {});
  when(() => translations.getCurrentLanguage()).thenReturn('es');
  when(() => translations.translate(any(), fallback: any(named: 'fallback')))
      .thenAnswer((call) => call.positionalArguments.first as String);
  when(() => translations.ensurePageTranslations(
        page: any(named: 'page'),
        requiredKeys: any(named: 'requiredKeys'),
      )).thenAnswer((_) async {});

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EventsController>.value(value: events),
        ChangeNotifierProvider<InvitationsController>.value(value: invitations),
        ChangeNotifierProvider<EventCoverUrlsController>.value(
          value: _CoverUrls(),
        ),
        ChangeNotifierProvider<TranslationsService>.value(value: translations),
      ],
      child: MaterialApp(
        home: const HomeShellPage(),
        routes: {
          CreateEventPage.routeName: (_) =>
              const Scaffold(body: Text('create event destination')),
        },
      ),
    ),
  );
  await tester.pump();
}
