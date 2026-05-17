import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/ui/ones_colors.dart';
import '../../../events/presentation/pages/event_detail_page.dart';
import '../invitations_controller.dart';

class InvitationLinkPage extends StatefulWidget {
  static const routeName = '/invitation';

  final String token;
  final String? action;

  const InvitationLinkPage({
    super.key,
    required this.token,
    this.action,
  });

  @override
  State<InvitationLinkPage> createState() => _InvitationLinkPageState();
}

class _InvitationLinkPageState extends State<InvitationLinkPage> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  Future<void> _run() async {
    final invitations = context.read<InvitationsController>();

    try {
      final api.Invitation inv =
          await invitations.repository.resolve(widget.token);

      final action = widget.action?.trim().toLowerCase();
      if (action == 'accept') {
        await invitations.accept(inv.eventId);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '${EventDetailPage.routeName}?eventId=${Uri.encodeComponent(inv.eventId)}&invitationStatus=accepted',
        );
        return;
      }

      if (action == 'reject') {
        await invitations.reject(inv.eventId);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      if (!mounted) return;
      await _showInvitationModal(inv);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _showInvitationModal(api.Invitation inv) async {
    final startAt = inv.eventStartAt.toLocal();
    final endAt = inv.eventEndAt.toLocal();

    Future<void> accept() async {
      await context.read<InvitationsController>().accept(inv.eventId);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacementNamed(
        '${EventDetailPage.routeName}?eventId=${Uri.encodeComponent(inv.eventId)}&invitationStatus=accepted',
      );
    }

    Future<void> reject() async {
      await context.read<InvitationsController>().reject(inv.eventId);
      if (!mounted) return;
      Navigator.of(context).pop();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: OnesColors.white,
          title: Text(inv.eventTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inv.eventLocation != null &&
                  inv.eventLocation!.trim().isNotEmpty) ...[
                Text(inv.eventLocation!),
                const SizedBox(height: 8),
              ],
              Text(startAt.toString()),
              Text(endAt.toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: reject,
              style: TextButton.styleFrom(foregroundColor: OnesColors.danger),
              child: const Text('Rechazar'),
            ),
            ElevatedButton(
              onPressed: accept,
              style: ElevatedButton.styleFrom(
                backgroundColor: OnesColors.purpleDeep,
                foregroundColor: OnesColors.white,
              ),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: OnesColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: OnesColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $_error'),
          ),
        ),
      );
    }

    if (widget.action?.trim().toLowerCase() == 'reject') {
      return const Scaffold(
        backgroundColor: OnesColors.background,
        body: Center(child: Text('Invitación rechazada.')),
      );
    }

    return const Scaffold(
      backgroundColor: OnesColors.background,
      body: Center(child: Text('Invitación procesada.')),
    );
  }
}
