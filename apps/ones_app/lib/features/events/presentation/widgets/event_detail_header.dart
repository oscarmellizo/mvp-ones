import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../invitations/presentation/invitations_controller.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../../tutorial/presentation/tutorial_controller.dart';

class EventDetailHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onBell;

  const EventDetailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final invitations = context.watch<InvitationsController>();
    final unread = invitations.unreadCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: OnesColors.black),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: TutorialKeys.eventHelpIcon,
          onPressed: () => TutorialController.instance.start(context),
          icon: const Icon(Icons.help_outline, color: OnesColors.black),
        ),
        const SizedBox(width: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onBell,
              icon:
                  const Icon(Icons.notifications_none, color: OnesColors.black),
            ),
            if (unread > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: OnesColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 99 ? '99+' : unread.toString(),
                    style: const TextStyle(
                      color: OnesColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
