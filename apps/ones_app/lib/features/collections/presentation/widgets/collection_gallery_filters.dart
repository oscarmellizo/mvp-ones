import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';

class CollectionGalleryFilters extends StatelessWidget {
  final bool privateCollection;
  final PhotosGalleryFilter selected;
  final String allLabel;
  final String sharedLabel;
  final String mineLabel;
  final String membersLabel;
  final Key? membersButtonKey;
  final bool memberSelectionEnabled;
  final int selectedMemberCount;
  final VoidCallback onMembersSelected;
  final ValueChanged<PhotosGalleryFilter> onSelected;

  const CollectionGalleryFilters({
    super.key,
    required this.privateCollection,
    required this.selected,
    required this.allLabel,
    required this.sharedLabel,
    required this.mineLabel,
    required this.membersLabel,
    required this.membersButtonKey,
    required this.memberSelectionEnabled,
    required this.selectedMemberCount,
    required this.onMembersSelected,
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
    final memberTooltip = selectedMemberCount > 0
        ? '$membersLabel ($selectedMemberCount)'
        : membersLabel;

    return ColoredBox(
      color: OnesColors.surfaceWarm,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            Expanded(
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
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: membersButtonKey,
              onPressed: memberSelectionEnabled ? onMembersSelected : null,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(48, 48),
              ),
              child: Tooltip(
                message: memberTooltip,
                child: Semantics(
                  label: memberTooltip,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.groups_outlined),
                          if (selectedMemberCount > 0)
                            Positioned(
                              right: -9,
                              top: -8,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: const BoxDecoration(
                                  color: OnesColors.orange,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  selectedMemberCount > 99
                                      ? '99+'
                                      : '$selectedMemberCount',
                                  style: const TextStyle(
                                    color: OnesColors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membersLabel,
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
          ],
        ),
      ),
    );
  }
}
