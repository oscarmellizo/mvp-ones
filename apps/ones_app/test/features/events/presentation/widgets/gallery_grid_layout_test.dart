import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/presentation/widgets/gallery_grid_layout.dart';

void main() {
  test('event gallery cards adapt from phone to tablet and desktop widths', () {
    expect(galleryCardColumns(360), 1);
    expect(galleryCardColumns(768), 2);
    expect(galleryCardColumns(1440), 4);
    expect(galleryCardColumns(1920), 5);
    expect(galleryGridWidth(1920), 1600);
  });

  test('photo tiles grow on web instead of reaching a tiny fixed width', () {
    expect(eventPhotoGridColumns(480), 3);
    expect(eventPhotoGridColumns(800), 3);
    expect(eventPhotoGridColumns(1024), 4);
    expect(eventPhotoGridColumns(1280), 5);
    expect(eventPhotoGridColumns(1920), 8);
    expect(eventPhotoGridAspectRatio(480), 0.82);
    expect(eventPhotoGridAspectRatio(800), 0.95);
    expect(eventPhotoGridAspectRatio(1280), 1.05);
  });
}
