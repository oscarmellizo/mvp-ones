import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/domain/event.dart';
import 'package:ones_app/features/events/presentation/event_cover_urls_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/galleries_page.dart';
import 'package:provider/provider.dart';

class _Events extends Mock implements EventsController {}

class _CoverUrls extends Mock implements EventCoverUrlsController {}

class _Translations extends Mock implements TranslationsService {}

Event _event(String id, String title, DateTime startAt) => Event(
      id: id,
      ownerId: 'user-1',
      createdAt: startAt,
      title: title,
      objective: 'test',
      location: 'Bogota',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 2)),
      coverKey: null,
      allowGuestInvites: false,
    );

void main() {
  Future<void> pumpGalleries(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final events = _Events();
    final covers = _CoverUrls();
    final translations = _Translations();
    when(() => events.events).thenReturn([
      _event('event-1', 'Galeria uno', DateTime(2025, 11, 19, 18)),
      _event('event-2', 'Galeria dos', DateTime(2025, 11, 18, 18)),
    ]);
    when(() => events.loading).thenReturn(false);
    when(() => events.refresh()).thenAnswer((_) async {});
    when(() => covers.getUrlIfAny(
          eventId: any(named: 'eventId'),
          coverKey: any(named: 'coverKey'),
        )).thenAnswer((_) async => null);
    when(() => translations.getCurrentLanguage()).thenReturn('es');
    when(() => translations.translate(
          any(),
          fallback: any(named: 'fallback'),
        )).thenAnswer((call) => call.positionalArguments.first as String);
    when(() => translations.ensurePageTranslations(
          page: any(named: 'page'),
          requiredKeys: any(named: 'requiredKeys'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EventsController>.value(value: events),
          ChangeNotifierProvider<EventCoverUrlsController>.value(value: covers),
          ChangeNotifierProvider<TranslationsService>.value(
            value: translations,
          ),
        ],
        child: const MaterialApp(home: GalleriesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wide gallery view places events from different dates in a grid',
      (tester) async {
    await pumpGalleries(tester, const Size(1200, 900));

    final firstTop = tester.getTopLeft(find.text('Galeria uno')).dy;
    final secondTop = tester.getTopLeft(find.text('Galeria dos')).dy;
    expect(secondTop, firstTop);
  });

  testWidgets('phone gallery view keeps the familiar day-by-day list',
      (tester) async {
    await pumpGalleries(tester, const Size(390, 844));

    final firstTop = tester.getTopLeft(find.text('Galeria uno')).dy;
    final secondTop = tester.getTopLeft(find.text('Galeria dos')).dy;
    expect(secondTop, greaterThan(firstTop));
  });
}
