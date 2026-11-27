import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';

class CollectionGalleryFilters extends StatelessWidget {
  final bool privateCollection;
  final PhotosGalleryFilter selected;
  final String allLabel;
  final String sharedLabel;
  final String mineLabel;
  final ValueChanged<PhotosGalleryFilter> onSelected;

  const CollectionGalleryFilters({
    super.key,
    required this.privateCollection,
    required this.selected,
    required this.allLabel,
    required this.sharedLabel,
    required this.mineLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (privateCollection) return const SizedBox.shrink();

    const filters = [
      PhotosGalleryFilter.all,
      PhotosGalleryFilter.sharedByMe,
      PhotosGalleryFilter.mine,
    ];
    const icons = {
      PhotosGalleryFilter.all: Icons.photo_library_outlined,
      PhotosGalleryFilter.sharedByMe: Icons.ios_share_outlined,
      PhotosGalleryFilter.mine: Icons.person_outline,
    };
    final labels = {
      PhotosGalleryFilter.all: allLabel,
      PhotosGalleryFilter.sharedByMe: sharedLabel,
      PhotosGalleryFilter.mine: mineLabel,
    };

    return ColoredBox(
      color: OnesColors.surfaceWarm,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: SegmentedButton<PhotosGalleryFilter>(
          showSelectedIcon: false,
          segments: filters
              .map(
                (filter) => ButtonSegment<PhotosGalleryFilter>(
                  value: filter,
                  label: Tooltip(
                    message: labels[filter]!,
                    child: Semantics(
                      label: labels[filter],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icons[filter]),
                          const SizedBox(height: 2),
                          Text(
                            labels[filter]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          selected: {selected},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onSelected(selection.first);
          },
        ),
      ),
    );
  }
}
