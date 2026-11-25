import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';

class EventDetailTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Key? galleryKey;
  final Key? detailsKey;
  final bool showTournament;

  const EventDetailTabs({
    super.key,
    required this.index,
    required this.onChanged,
    this.galleryKey,
    this.detailsKey,
    this.showTournament = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final bg = OnesColors.surfaceWarm;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(OnesColors.black.withOpacity(0.04), bg),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              key: galleryKey,
              label: t.translate(
                'event_detail.tab_gallery',
                fallback: 'Gallery',
              ),
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              key: detailsKey,
              label: t.translate(
                'event_detail.tab_details',
                fallback: 'Details',
              ),
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
          if (showTournament) ...[
            const SizedBox(width: 4),
            Expanded(
              child: _TabButton(
                label: 'Torneo',
                selected: index == 2,
                onTap: () => onChanged(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OnesColors.white : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: OnesColors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? OnesColors.purpleMid : Colors.black54,
          ),
        ),
      ),
    );
  }
}
