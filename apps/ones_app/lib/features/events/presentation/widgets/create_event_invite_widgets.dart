import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';

class CreateEventInvitee {
  final String name;
  final String email;

  const CreateEventInvitee({
    required this.name,
    required this.email,
  });
}

class CreateEventInviteGuestsCard extends StatelessWidget {
  final TextEditingController emailController;
  final String? inviteError;
  final List<CreateEventInvitee> invitees;
  final Future<void> Function() onInvite;
  final ValueChanged<CreateEventInvitee> onRemove;

  const CreateEventInviteGuestsCard({
    super.key,
    required this.emailController,
    required this.inviteError,
    required this.invitees,
    required this.onInvite,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return OnesCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invite Guests',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                '${invitees.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: OnesColors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OnesTextField(
            controller: emailController,
            hintText: 'Add emails (comma/space separated)',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            onSubmitted: (_) {
              onInvite();
            },
          ),
          if (inviteError != null) ...[
            const SizedBox(height: 10),
            Text(
              inviteError!,
              style: const TextStyle(
                color: OnesColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OnesColors.purpleMid,
                foregroundColor: OnesColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () {
                onInvite();
              },
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Invited',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (invitees.isEmpty)
            Text(
              'No invited guests yet.',
              style: TextStyle(color: OnesColors.black.withOpacity(0.55)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: invitees
                  .map(
                    (invitee) => InputChip(
                      label: Tooltip(
                        message: invitee.email,
                        child: Text(
                          invitee.name.trim().isNotEmpty &&
                                  invitee.name != invitee.email
                              ? invitee.name
                              : invitee.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: () => onRemove(invitee),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
