import 'package:flutter/material.dart';

import '../../features/events/domain/event.dart';
import '../ui/ones_colors.dart';

class LiveEventsSelector extends StatelessWidget {
  final List<Event> liveEvents;
  final void Function(String eventId, bool openCamera) onSelect;

  const LiveEventsSelector({
    super.key,
    required this.liveEvents,
    required this.onSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Event> liveEvents,
    required void Function(String eventId, bool openCamera) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OnesColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => LiveEventsSelector(
        liveEvents: liveEvents,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OnesColors.purpleMid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Eventos en vivo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...liveEvents.map((event) => _EventTile(
                  event: event,
                  onGallery: () {
                    Navigator.of(context).pop();
                    onSelect(event.id, false);
                  },
                  onCamera: () {
                    Navigator.of(context).pop();
                    onSelect(event.id, true);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _EventTile({
    required this.event,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  event.location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ver galería',
            icon: const Icon(Icons.photo_library_outlined),
            color: OnesColors.purpleMid,
            onPressed: onGallery,
          ),
          IconButton(
            tooltip: 'Tomar foto',
            icon: const Icon(Icons.camera_alt_outlined),
            color: OnesColors.purpleMid,
            onPressed: onCamera,
          ),
        ],
      ),
    );
  }
}
