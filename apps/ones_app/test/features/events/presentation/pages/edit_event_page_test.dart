import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/adapters/api/event_complements_api_repository.dart';
import 'package:ones_app/features/events/adapters/api/event_covers_api_repository.dart';
import 'package:ones_app/features/events/domain/event.dart';
import 'package:ones_app/features/events/presentation/event_covers_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/edit_event_page.dart';
import 'package:provider/provider.dart';

class _MockEvents extends Mock implements EventsController {}

class _MockComplements extends Mock implements EventComplementsApiRepository {}

class _MockTranslations extends Mock implements TranslationsService {}

class _MockDefaultApi extends Mock implements api.DefaultApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.utc(2025));
    registerFallbackValue(<String>[]);
  });

  testWidgets('enabling tournament from edit persists it and saves event',
      (tester) async {
    final now = DateTime.now();
    final event = Event(
      id: 'event-1',
      ownerId: 'owner-1',
      createdAt: now,
      title: 'Birthday',
      objective: 'Celebrate',
      location: 'Home',
      startAt: now.add(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 1, hours: 2)),
      coverKey: null,
      allowGuestInvites: true,
    );
    final events = _MockEvents();
    final complements = _MockComplements();
    final translations = _MockTranslations();
    final covers = EventCoversController(
      repository: EventCoversApiRepository.forTesting(
        (_) => _MockDefaultApi(),
      ),
    );

    when(() => translations.getCurrentLanguage()).thenReturn('es');
    when(
      () => translations.translate(
        any(),
        fallback: any(named: 'fallback'),
      ),
    ).thenAnswer((call) {
      return call.namedArguments[#fallback] as String? ??
          call.positionalArguments.first as String;
    });
    when(
      () => translations.ensurePageTranslations(
        page: any(named: 'page'),
        requiredKeys: any(named: 'requiredKeys'),
      ),
    ).thenAnswer((_) async {});
    when(() => complements.list('event-1')).thenAnswer(
      (_) async => [
        {'id': 'tournament', 'enabled': false},
      ],
    );
    when(
      () => events.updateEvent(
        eventId: 'event-1',
        title: any(named: 'title'),
        objective: any(named: 'objective'),
        location: any(named: 'location'),
        startAt: any(named: 'startAt'),
        endAt: any(named: 'endAt'),
        allowGuestInvites: true,
        frameIds: any(named: 'frameIds'),
        coverReservationId: null,
      ),
    ).thenAnswer((_) async {});
    when(
      () => complements.setEnabled(
        eventId: 'event-1',
        complementId: 'tournament',
        enabled: true,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsController>.value(value: events),
          Provider<EventComplementsApiRepository>.value(value: complements),
          ChangeNotifierProvider<TranslationsService>.value(
            value: translations,
          ),
          ChangeNotifierProvider<EventCoversController>.value(
            value: covers,
          ),
        ],
        child: MaterialApp(
          home: EditEventPage(initial: event),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchTile =
        find.byKey(const Key('edit_event.tournament_complement'));
    expect(switchTile, findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(switchTile).value,
      isFalse,
    );

    await tester.ensureVisible(switchTile);
    await tester.pumpAndSettle();
    await tester.tap(switchTile);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    verify(
      () => events.updateEvent(
        eventId: 'event-1',
        title: 'Birthday',
        objective: 'Celebrate',
        location: 'Home',
        startAt: any(named: 'startAt'),
        endAt: any(named: 'endAt'),
        allowGuestInvites: true,
        frameIds: <String>[],
        coverReservationId: null,
      ),
    ).called(1);
    verify(
      () => complements.setEnabled(
        eventId: 'event-1',
        complementId: 'tournament',
        enabled: true,
      ),
    ).called(1);
    covers.dispose();
  });
}
