import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../events/presentation/events_controller.dart';
import '../invitations_controller.dart';

Future<void> showInvitationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _InvitationsSheet(),
  ).whenComplete(() async {
    if (!context.mounted) return;
    await context.read<EventsController>().refresh();
  });
}

class _InvitationsSheet extends StatefulWidget {
  const _InvitationsSheet();

  @override
  State<_InvitationsSheet> createState() => _InvitationsSheetState();
}

class _InvitationsSheetState extends State<_InvitationsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<InvitationsController>();
      controller.refresh().then((_) => controller.markAllSeen());
    });
  }

  @override
  Widget build(BuildContext context) {
    final invites = context.watch<InvitationsController>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: const BoxDecoration(
            color: OnesColors.white,
            borderRadius: BorderRadius.zero,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.80,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Invitations',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                ),
                if (invites.loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (invites.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No invitations.',
                      style:
                          TextStyle(color: OnesColors.black.withOpacity(0.6)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: invites.items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 16,
                        color: OnesColors.black.withOpacity(0.08),
                      ),
                      itemBuilder: (context, index) {
                        final inv = invites.items[index];
                        return _InvitationRow(
                          eventId: inv.eventId,
                          title: inv.eventTitle,
                          status: inv.status,
                          startAt: inv.eventStartAt,
                          endAt: inv.eventEndAt,
                          location: inv.eventLocation,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitationRow extends StatelessWidget {
  final String eventId;
  final String title;
  final api.InvitationStatusEnum status;
  final DateTime startAt;
  final DateTime endAt;
  final String? location;

  const _InvitationRow({
    required this.eventId,
    required this.title,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<InvitationsController>();

    final when =
        '${formatMonthDayYear(startAt.toLocal())} • ${formatTimeOfDay(startAt.toLocal())}';
    final loc =
        (location == null || location!.trim().isEmpty) ? '-' : location!.trim();

    final (chipText, chipColor) = switch (status) {
      api.InvitationStatusEnum.accepted => ('Accepted', OnesColors.green),
      api.InvitationStatusEnum.rejected => ('Rejected', OnesColors.danger),
      api.InvitationStatusEnum.invited => ('Invited', OnesColors.yellowSoft),
      _ => ('Invited', OnesColors.yellowSoft),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$when • $loc',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                chipText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: controller.loading
                    ? null
                    : () async {
                        await controller.reject(eventId);
                        if (context.mounted) {
                          await context.read<EventsController>().refresh();
                        }
                      },
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OnesColors.purpleMid,
                  foregroundColor: OnesColors.white,
                ),
                onPressed: controller.loading
                    ? null
                    : () async {
                        await controller.accept(eventId);
                        if (context.mounted) {
                          await context.read<EventsController>().refresh();
                        }
                      },
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
