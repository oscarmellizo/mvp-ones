import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/photos/adapters/api/event_photos_api.dart';
import 'package:ones_app/features/photos/domain/event_photo.dart';
import 'package:ones_app/features/photos/presentation/photos_gallery_controller.dart';

class _MockApi extends Mock implements EventPhotosApi {}

EventPhoto _photo(String id, int minute) => EventPhoto(
      photoId: id,
      guestId: 'g1',
      createdAt: DateTime.utc(2026, 10, 2, 12, minute),
      uploadedAt: null,
      status: 'READY',
      originalUrl: null,
      mediumUrl: null,
      smallUrl: null,
      shared: false,
      ownerName: null,
      sharedByUserId: null,
      sharedByName: null,
      likedByMe: false,
    );

void main() {
  late _MockApi api;
  late PhotosGalleryController controller;

  setUp(() {
    api = _MockApi();
    controller = PhotosGalleryController(api: api);
    controller.setIdToken('t');
  });

  void serve(List<EventPhoto> items) {
    when(() => api.list(
          eventId: any(named: 'eventId'),
          limit: any(named: 'limit'),
          nextToken: any(named: 'nextToken'),
          scope: any(named: 'scope'),
          filter: any(named: 'filter'),
          guestIds: any(named: 'guestIds'),
        )).thenAnswer((_) async => ListPhotosPage(items: items, nextToken: null));
  }

  test('deslizar para actualizar quita las fotos borradas en el servidor', () async {
    serve([_photo('p1', 1), _photo('p2', 2)]);
    await controller.refresh(eventId: 'e1');
    expect(controller.items.map((p) => p.photoId), ['p2', 'p1']);

    serve([_photo('p1', 1)]); // p2 se borró en el servidor
    await controller.refresh(eventId: 'e1', replace: true);

    expect(controller.items.map((p) => p.photoId), ['p1']);
  });
}
