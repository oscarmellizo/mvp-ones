import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/collections/presentation/widgets/collection_gallery_filters.dart';
import 'package:ones_app/features/photos/presentation/photos_gallery_controller.dart';

void main() {
  testWidgets('collection filters match the event gallery and update selection',
      (tester) async {
    var selected = PhotosGalleryFilter.all;
    var memberFilterOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionGalleryFilters(
            privateCollection: false,
            selected: selected,
            allLabel: 'Todas',
            sharedLabel: 'Compartidas',
            mineLabel: 'Mías',
            membersLabel: 'Miembros',
            membersButtonKey: const ValueKey('members-filter'),
            memberSelectionEnabled: true,
            onMembersSelected: () => memberFilterOpened = true,
            onSelected: (filter) => selected = filter,
          ),
        ),
      ),
    );

    final button = tester.widget<SegmentedButton<PhotosGalleryFilter>>(
      find.byType(SegmentedButton<PhotosGalleryFilter>),
    );
    expect(
      button.segments.map((segment) => segment.value),
      [
        PhotosGalleryFilter.all,
        PhotosGalleryFilter.sharedByMe,
        PhotosGalleryFilter.mine,
      ],
    );
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Compartidas'), findsOneWidget);
    expect(find.text('Mías'), findsOneWidget);

    await tester.tap(find.text('Compartidas'));
    await tester.pumpAndSettle();
    expect(selected, PhotosGalleryFilter.sharedByMe);
    await tester.tap(find.text('Miembros'));
    expect(memberFilterOpened, isTrue);
  });

  testWidgets('private collections do not show gallery filters',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionGalleryFilters(
            privateCollection: true,
            selected: PhotosGalleryFilter.all,
            allLabel: 'Todas',
            sharedLabel: 'Compartidas',
            mineLabel: 'Mías',
            membersLabel: 'Miembros',
            membersButtonKey: const ValueKey('members-filter'),
            memberSelectionEnabled: true,
            onMembersSelected: () {},
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<PhotosGalleryFilter>), findsNothing);
    expect(find.text('Compartidas'), findsNothing);
    expect(find.text('Miembros'), findsNothing);
  });
}
