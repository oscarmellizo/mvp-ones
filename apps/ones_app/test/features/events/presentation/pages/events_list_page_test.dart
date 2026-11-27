import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/domain/event.dart';
import 'package:ones_app/features/events/presentation/event_cover_urls_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/events_list_page.dart';
import 'package:ones_app/features/invitations/presentation/invitations_controller.dart';
import 'package:provider/provider.dart';

class _Events extends Mock implements EventsController {}

class _Invitations extends Mock implements InvitationsController {}

class _CoverUrls extends Mock implements EventCoverUrlsController {}

class _Translations extends Mock implements TranslationsService {}

Event _event(
  String id,
  String title,
  DateTime startAt, {
  String location = 'Bogota',
}) =>
    Event(
      id: id,
      ownerId: 'user-1',
      createdAt: startAt,
      title: title,
      objective: 'test',
      location: location,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 2)),
      coverKey: null,
      allowGuestInvites: false,
    );

void main() {
  Future<void> pumpEventsList(
    WidgetTester tester, {
    List<Event> items = const [],
  }) async {
    final events = _Events();
    final invitations = _Invitations();
    final covers = _CoverUrls();
    final translations = _Translations();
    when(() => events.events).thenReturn(items);
    when(() => events.loading).thenReturn(false);
    when(() => events.error).thenReturn(null);
    when(() => events.refresh()).thenAnswer((_) async {});
    when(() => invitations.unreadCount).thenReturn(0);
    when(() => invitations.refresh()).thenAnswer((_) async {});
    when(() => covers.getUrlIfAny(
          eventId: any(named: 'eventId'),
          coverKey: any(named: 'coverKey'),
        )).thenAnswer((_) async => null);
    when(() => translations.getCurrentLanguage()).thenReturn('es');
    when(() => translations.translate(any(), fallback: any(named: 'fallback')))
        .thenAnswer((call) => call.positionalArguments.first as String);
    when(() => translations.ensurePageTranslations(
          page: any(named: 'page'),
          requiredKeys: any(named: 'requiredKeys'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<EventsController>.value(value: events),
        ChangeNotifierProvider<InvitationsController>.value(value: invitations),
        ChangeNotifierProvider<EventCoverUrlsController>.value(value: covers),
        ChangeNotifierProvider<TranslationsService>.value(value: translations),
      ],
      child: MaterialApp(
        home: Scaffold(
            body: Builder(builder: (context) => const EventsListPage())),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('la lista de eventos no duplica el encabezado de Home',
      (tester) async {
    await pumpEventsList(tester);

    expect(find.byTooltip('Plus'), findsNothing);
    expect(find.byTooltip('Menú'), findsNothing);
    expect(find.byTooltip('Ayuda'), findsNothing);
  });

  testWidgets('buscador filtra eventos por título y ubicación', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, now.hour);
    await pumpEventsList(
      tester,
      items: [
        _event('e1', 'Fiesta fin de año', today),
        _event('e2', 'Cumpleanos mama', today, location: 'Medellin'),
      ],
    );

    expect(find.text('Fiesta fin de año'), findsOneWidget);
    expect(find.text('Cumpleanos mama'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fiesta');
    await tester.pumpAndSettle();

    expect(find.text('Fiesta fin de año'), findsOneWidget);
    expect(find.text('Cumpleanos mama'), findsNothing);

    await tester.enterText(find.byType(TextField), 'medellin');
    await tester.pumpAndSettle();

    expect(find.text('Fiesta fin de año'), findsNothing);
    expect(find.text('Cumpleanos mama'), findsOneWidget);
  });
}
