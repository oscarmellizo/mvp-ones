import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../../events/domain/event.dart';
import '../../../events/presentation/event_cover_urls_controller.dart';
import '../../../events/presentation/events_controller.dart';
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
      Event? event;
      String? coverUrl;
      try {
        final eventsController = context.read<EventsController>();
        final coverUrlsController = context.read<EventCoverUrlsController>();

        event = await eventsController.getEvent.execute(inv.eventId);
        coverUrl = await coverUrlsController.getUrlIfAny(
          eventId: event.id,
          coverKey: event.coverKey,
        );
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      await _showInvitationModal(inv, event: event, coverUrl: coverUrl);

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

  Future<void> _showInvitationModal(
    api.Invitation inv, {
    required Event? event,
    required String? coverUrl,
  }) async {
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
        Widget buildCoverFallback() {
          return ColoredBox(
            color: OnesColors.white,
            child: Center(
              child: Image.asset(
                'assets/branding/ones-logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
          );
        }

        final subtitle = (inv.eventLocation == null ||
                inv.eventLocation!.trim().isEmpty)
            ? formatMonthDayYear(startAt)
            : '${formatMonthDayYear(startAt)} • ${inv.eventLocation!.trim()}';

        final timeRange =
            '${formatTimeOfDay(startAt)} - ${formatTimeOfDay(endAt)}';

        final objective = event?.objective.trim() ?? '';

        return AlertDialog(
          backgroundColor: OnesColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: (coverUrl != null && coverUrl.trim().isNotEmpty)
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildCoverFallback(),
                      )
                    : buildCoverFallback(),
              ),
              const SizedBox(height: 12),
              Text(
                inv.eventTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: OnesColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: OnesColors.black.withOpacity(0.65),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                timeRange,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: OnesColors.black,
                ),
              ),
              if (objective.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  objective,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: OnesColors.black.withOpacity(0.75),
                  ),
                ),
              ],
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
