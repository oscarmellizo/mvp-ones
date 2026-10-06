import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/events/presentation/event_cover_urls_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/events_list_page.dart';
import 'package:ones_app/features/invitations/presentation/invitations_controller.dart';
import 'package:provider/provider.dart';

class _Events extends Mock implements EventsController {}
class _Invitations extends Mock implements InvitationsController {}
class _CoverUrls extends Mock implements EventCoverUrlsController {}
class _Translations extends Mock implements TranslationsService {}

void main() {
  testWidgets('Inicio no ofrece planes y conserva menú e invitaciones',
      (tester) async {
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

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<EventsController>.value(value: events),
        ChangeNotifierProvider<InvitationsController>.value(value: invitations),
        ChangeNotifierProvider<EventCoverUrlsController>.value(value: _CoverUrls()),
        ChangeNotifierProvider<TranslationsService>.value(value: translations),
      ],
      child: MaterialApp(
        home: Scaffold(body: Builder(builder: (context) => const EventsListPage())),
      ),
    ));
    await tester.pump();

    expect(find.byTooltip('Plus'), findsNothing);
    expect(find.byTooltip('Menú'), findsOneWidget);
    expect(find.byTooltip('Ayuda'), findsOneWidget);
  });
}
