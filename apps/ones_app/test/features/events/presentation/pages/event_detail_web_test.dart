import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/app.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/events/presentation/pages/event_detail_page.dart';
import 'package:ones_app/features/photos/adapters/api/event_photos_api.dart';
import 'package:ones_app/features/photos/adapters/local/photo_storage.dart';
import 'package:ones_app/features/photos/adapters/local/photo_upload_db.dart';
import 'package:ones_app/features/photos/presentation/photos_upload_controller.dart';
import 'package:ones_app/features/tutorial/domain/tutorial_version.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements AuthController {}
class _Events extends Mock implements EventsController {}
class _Translations extends Mock implements TranslationsService {}
class _PhotosApi extends Mock implements EventPhotosApi {}
class _UploadDb extends Mock implements PhotoUploadDb {}
class _Storage extends Mock implements PhotoStorage {}

void main() {
  test('ruta inicial /events/detail obtiene eventId de la URL web completa', () {
    expect(
      eventIdForRoute(
        '/events/detail',
        Uri.parse('https://app.ones.events/events/detail?eventId=event-1'),
      ),
      'event-1',
    );
    expect(
      eventIdForRoute(
        '/events/detail?eventId=event-2',
        Uri.parse('https://app.ones.events/events/detail?eventId=event-1'),
      ),
      'event-2',
    );
    expect(
      eventIdForRoute('/events/detail', Uri.parse('https://app.ones.events/')),
      isNull,
    );
  });

  test('web no abre base local ni cola al iniciar/cerrar sesión', () async {
    final db = _UploadDb();
    final api = _PhotosApi();
    final uploader = PhotosUploadController(
      api: api,
      db: db,
      storage: _Storage(),
      useLocalQueue: false,
    );
    uploader.setIdToken('test-token');
    await uploader.trigger();
    await uploader.rehydrateActive();
    await uploader.markDoneByPhotoId(eventId: 'event-1', photoId: 'photo-1');
    uploader.setIdToken(null);
    await Future<void>.delayed(Duration.zero);
    expect(uploader.activeByEvent('event-1'), isEmpty);
    verify(() => api.setIdToken('test-token')).called(1);
    verifyNever(() => db.clearAll());
    verifyNever(() => db.listActive());
    uploader.dispose();
  });
  testWidgets('la galería puede abrir cámara sin Hero duplicado', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ones.tutorial_seen./events/detail': true,
      'ones.tutorial_version./events/detail': kTutorialVersion,
    });
    final auth = _Auth();
    final events = _Events();
    final translations = _Translations();
    final api = _PhotosApi();
    when(() => auth.idToken).thenReturn(null);
    when(() => auth.user).thenReturn(null);
    when(() => events.selected).thenReturn(null);
    when(() => events.selectedError).thenReturn(null);
    when(() => events.select(any())).thenAnswer((_) async {});
    when(() => translations.getCurrentLanguage()).thenReturn('es');
    when(() => translations.ensurePageTranslations(
          page: any(named: 'page'),
          requiredKeys: any(named: 'requiredKeys'),
        )).thenAnswer((_) async {});
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<EventsController>.value(value: events),
        ChangeNotifierProvider<TranslationsService>.value(value: translations),
        Provider<EventPhotosApi>.value(value: api),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const EventDetailPage(eventId: 'event-1'),
      ),
    ));
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsNWidgets(2));

    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Cámara abierta')),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
