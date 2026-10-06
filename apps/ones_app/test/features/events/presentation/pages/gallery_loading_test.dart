import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/events/application/create_event_use_case.dart';
import 'package:ones_app/features/events/application/get_event_use_case.dart';
import 'package:ones_app/features/events/application/list_events_use_case.dart';
import 'package:ones_app/features/events/application/update_event_use_case.dart';
import 'package:ones_app/features/events/domain/event.dart';
import 'package:ones_app/features/events/domain/events_repository.dart';
import 'package:ones_app/features/events/presentation/events_controller.dart';
import 'package:ones_app/features/photos/adapters/api/event_photos_api.dart';
import 'package:ones_app/features/photos/domain/event_photo.dart';
import 'package:ones_app/features/photos/presentation/photos_gallery_controller.dart';

class _EventsRepository extends Mock implements EventsRepository {}
class _PhotosApi extends Mock implements EventPhotosApi {}

Event _event(String id) => Event(
      id: id,
      ownerId: 'user-1',
      createdAt: DateTime.utc(2025),
      title: 'Evento $id',
      objective: 'test',
      location: 'Bogotá',
      startAt: DateTime.utc(2025),
      endAt: DateTime.utc(2025, 1, 2),
      coverKey: null,
      allowGuestInvites: false,
    );

void main() {
  late _EventsRepository repository;
  late EventsController controller;

  setUp(() {
    repository = _EventsRepository();
    controller = EventsController(
      listEvents: ListEventsUseCase(repository),
      getEvent: GetEventUseCase(repository),
      createEvent: CreateEventUseCase(repository),
      updateEventUseCase: UpdateEventUseCase(repository),
      eventsRepository: repository,
    );
    when(() => repository.getEvent(any())).thenAnswer(
      (invocation) async => _event(invocation.positionalArguments.first as String),
    );
  });

  tearDown(() => controller.dispose());

  test('renovar token de la misma cuenta conserva el evento seleccionado', () async {
    controller.setIdToken('token-1', userId: 'user-1');
    await controller.select('event-1');

    controller.setIdToken('token-2', userId: 'user-1');

    expect(controller.selected?.id, 'event-1');
    expect(controller.loading, isFalse);
  });

  test('fallo de listado no borra el detalle ya cargado', () async {
    controller.setIdToken('token-1', userId: 'user-1');
    await controller.select('event-1');
    when(() => repository.listEvents()).thenThrow(StateError('sin conexión'));

    await controller.refresh();

    expect(controller.selected?.id, 'event-1');
    expect(controller.error, isNotNull);
  });

  test('carga de lista paralela no borra el detalle', () async {
    final pending = Completer<List<Event>>();
    controller.setIdToken('token-1', userId: 'user-1');
    await controller.select('event-1');
    when(() => repository.listEvents()).thenAnswer((_) => pending.future);

    final refresh = controller.refresh();
    expect(controller.selected?.id, 'event-1');

    pending.completeError(StateError('sin conexión'));
    await refresh;
    expect(controller.selected?.id, 'event-1');
  });

  test('logout y cambio de usuario limpian eventos de la cuenta anterior', () async {
    controller.setIdToken('token-1', userId: 'user-1');
    await controller.select('event-1');

    controller.setIdToken(null);
    expect(controller.selected, isNull);

    controller.setIdToken('token-2', userId: 'user-2');
    await controller.select('event-2');
    controller.setIdToken('token-3', userId: 'user-3');
    expect(controller.selected, isNull);
  });

  test('respuesta anterior a un cambio de usuario no repone evento viejo', () async {
    final pending = Completer<Event>();
    when(() => repository.getEvent('event-1')).thenAnswer((_) => pending.future);
    controller.setIdToken('token-1', userId: 'user-1');
    final oldRequest = controller.select('event-1');

    controller.setIdToken('token-2', userId: 'user-2');
    pending.complete(_event('event-1'));
    await oldRequest;

    expect(controller.selected, isNull);
  });

  test('mismo token con otro usuario invalida el evento previo', () async {
    controller.setIdToken('token-1', userId: 'user-1');
    await controller.select('event-1');

    controller.setIdToken('token-1', userId: 'user-2');

    expect(controller.selected, isNull);
  });

  test('respuesta anterior a otra selección no reemplaza el evento actual', () async {
    final pending = Completer<Event>();
    when(() => repository.getEvent('event-1')).thenAnswer((_) => pending.future);
    controller.setIdToken('token-1', userId: 'user-1');
    final oldRequest = controller.select('event-1');
    await controller.select('event-2');
    expect(controller.loading, isTrue);
    pending.complete(_event('event-1'));
    await oldRequest;

    expect(controller.selected?.id, 'event-2');
    expect(controller.loading, isFalse);
  });

  test('fallo de carga inicial permite reintentar selección', () async {
    controller.setIdToken('token-1', userId: 'user-1');
    when(() => repository.getEvent('event-1')).thenThrow(StateError('offline'));
    await controller.select('event-1');

    expect(controller.loading, isFalse);
    expect(controller.error, isNotNull);
    expect(controller.selectedError, isNotNull);
    expect(controller.selected, isNull);
    when(() => repository.listEvents()).thenThrow(StateError('list offline'));
    await controller.refresh();
    expect(controller.selectedError, isNotNull);

    when(() => repository.getEvent('event-1')).thenAnswer((_) async => _event('event-1'));
    await controller.select('event-1');
    expect(controller.selected?.id, 'event-1');
    expect(controller.error, isNull);
    expect(controller.selectedError, isNull);
  });

  test('respuesta vieja de listado no borra datos de otra sesión', () async {
    final pending = Completer<List<Event>>();
    when(() => repository.listEvents()).thenAnswer((_) => pending.future);
    controller.setIdToken('token-1', userId: 'user-1');
    final oldRequest = controller.refresh();
    controller.setIdToken('token-2', userId: 'user-2');
    pending.complete([_event('event-1')]);
    await oldRequest;

    expect(controller.events, isEmpty);
    expect(controller.loading, isFalse);
  });

  test('refrescar fotos del mismo evento mantiene fotos durante la espera', () async {
    final api = _PhotosApi();
    final pending = Completer<ListPhotosPage>();
    when(() => api.setIdToken(any())).thenReturn(null);
    when(() => api.list(eventId: 'event-1', limit: 24, filter: 'all'))
        .thenAnswer((_) async => const ListPhotosPage(
              items: [EventPhoto(
                photoId: 'photo-1',
                guestId: 'user-1',
                createdAt: null,
                uploadedAt: null,
                status: 'ready',
                originalUrl: null,
                mediumUrl: null,
                smallUrl: null,
                shared: false,
                ownerName: null,
                sharedByUserId: null,
                sharedByName: null,
                likedByMe: false,
              )],
              nextToken: null,
            ));
    final gallery = PhotosGalleryController(api: api)
      ..setIdToken('token-1')
      ..prepare(eventId: 'event-1');
    addTearDown(gallery.dispose);
    await gallery.refresh(eventId: 'event-1');
    when(() => api.list(eventId: 'event-1', limit: 24, filter: 'all'))
        .thenAnswer((_) => pending.future);

    final refresh = gallery.refresh(eventId: 'event-1');
    expect(gallery.loading, isTrue);
    expect(gallery.loadedOnce, isTrue);
    expect(gallery.items.map((p) => p.photoId), contains('photo-1'));
    pending.complete(const ListPhotosPage(items: [], nextToken: null));
    await refresh;
    expect(gallery.loading, isFalse);
    expect(gallery.items.map((p) => p.photoId), contains('photo-1'));
  });

  test('token tardío reactiva una sola carga pendiente de galería', () async {
    final api = _PhotosApi();
    when(() => api.setIdToken(any())).thenReturn(null);
    when(() => api.list(eventId: 'event-1', limit: 24, filter: 'all'))
        .thenAnswer((_) async => const ListPhotosPage(items: [], nextToken: null));
    final gallery = PhotosGalleryController(api: api)..prepare(eventId: 'event-1');
    addTearDown(gallery.dispose);
    await gallery.refresh(eventId: 'event-1');
    expect(gallery.loadedOnce, isFalse);

    final loaded = Completer<void>();
    gallery.addListener(() {
      if (gallery.loadedOnce && !loaded.isCompleted) loaded.complete();
    });
    gallery.setIdToken('token-1');
    await loaded.future.timeout(const Duration(seconds: 3));
    expect(gallery.loadedOnce, isTrue);
    expect(gallery.loading, isFalse);
    verify(() => api.list(eventId: 'event-1', limit: 24, filter: 'all')).called(2);
  });
}
