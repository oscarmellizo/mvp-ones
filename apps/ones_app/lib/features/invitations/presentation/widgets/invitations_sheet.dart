import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../collections/domain/collection_invitation.dart';
import '../../../collections/presentation/collections_controller.dart';
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
            borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                if (invites.collectionError != null &&
                    (invites.items.isNotEmpty ||
                        invites.collectionItems.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: OnesColors.danger),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No se pudieron cargar las invitaciones de colecciones.',
                          ),
                        ),
                        TextButton(
                          onPressed: invites.loading ? null : invites.refresh,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                if (invites.loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (invites.items.isEmpty &&
                    invites.collectionItems.isEmpty &&
                    (invites.error != null || invites.collectionError != null))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          invites.collectionError != null
                              ? 'No se pudieron cargar las invitaciones de colecciones.'
                              : 'No se pudieron cargar las invitaciones.',
                        ),
                        TextButton(
                          onPressed: invites.refresh,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (invites.items.isEmpty &&
                    invites.collectionItems.isEmpty)
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
                      itemCount: invites.collectionItems.length +
                          invites.items.length +
                          (invites.collectionHasMore ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                        height: 16,
                        color: OnesColors.black.withOpacity(0.08),
                      ),
                      itemBuilder: (context, index) {
                        if (index < invites.collectionItems.length) {
                          return _CollectionInvitationRow(
                            invitation: invites.collectionItems[index],
                          );
                        }
                        final eventIndex =
                            index - invites.collectionItems.length;
                        if (eventIndex >= invites.items.length) {
                          return Center(
                            child: TextButton(
                              onPressed: invites.loading
                                  ? null
                                  : () async {
                                      try {
                                        await invites
                                            .loadMoreCollectionInvitations();
                                        await invites.markAllSeen();
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: const Text('Ver más invitaciones'),
                            ),
                          );
                        }
                        final inv = invites.items[eventIndex];
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

class _CollectionInvitationRow extends StatelessWidget {
  final CollectionInvitation invitation;

  const _CollectionInvitationRow({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<InvitationsController>();
    final createdAt = formatMonthDayYear(invitation.createdAt.toLocal());

    Future<void> respond(bool accept) async {
      try {
        if (accept) {
          await controller.acceptCollection(invitation.collectionId);
          if (context.mounted) {
            await context.read<CollectionsController>().refresh();
          }
        } else {
          await controller.rejectCollection(invitation.collectionId);
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 10, top: 2),
              child: Icon(
                Icons.collections_bookmark_outlined,
                color: OnesColors.purpleMid,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation.collectionName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Te invitaron a una colección · $createdAt',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: controller.loading ? null : () => respond(false),
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OnesColors.purpleMid,
                  foregroundColor: OnesColors.white,
                ),
                onPressed: controller.loading ? null : () => respond(true),
                child: const Text('Aceptar'),
              ),
            ),
          ],
        ),
      ],
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
                borderRadius: const BorderRadius.all(Radius.circular(12)),
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
