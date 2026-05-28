import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../adapters/api/events_api_repository.dart';
import '../../domain/events_repository.dart';
import '../event_cover_urls_controller.dart';
import 'event_detail_page.dart';

class EventInviteLinkPage extends StatefulWidget {
  static const routeName = '/event-invite';

  final String eventId;
  final String sig;

  const EventInviteLinkPage({
    super.key,
    required this.eventId,
    required this.sig,
  });

  @override
  State<EventInviteLinkPage> createState() => _EventInviteLinkPageState();
}

class _EventInviteLinkPageState extends State<EventInviteLinkPage> {
  Future<EventInviteLinkPreview>? _future;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _future = context
        .read<EventsRepository>()
        .previewInviteLink(widget.eventId, widget.sig);
  }

  @override
  Widget build(BuildContext context) {
    final previewFuture = _future;
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: previewFuture == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<EventInviteLinkPreview>(
                  future: previewFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'Invite link is not available.',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: OnesColors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This link may be invalid, disabled, or expired.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: OnesColors.black.withOpacity(0.65),
                            ),
                          ),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OnesColors.purpleMid,
                              foregroundColor: OnesColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Back',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      );
                    }

                    final preview = snapshot.data!;
                    final startAt = preview.startAt.toLocal();
                    final endAt = preview.endAt.toLocal();
                    final subtitle = preview.location.trim().isEmpty
                        ? formatMonthDayYear(startAt)
                        : '${formatMonthDayYear(startAt)} • ${preview.location.trim()}';
                    final timeRange =
                        '${formatTimeOfDay(startAt)} - ${formatTimeOfDay(endAt)}';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Event invite',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: OnesColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<String?>(
                          future: context
                              .read<EventCoverUrlsController>()
                              .getUrlIfAny(
                                eventId: preview.id,
                                coverKey: preview.coverKey,
                              ),
                          builder: (context, coverSnapshot) {
                            final url = coverSnapshot.data;

                            Widget fallback() {
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

                            return AspectRatio(
                              aspectRatio: 16 / 9,
                              child: (url != null && url.trim().isNotEmpty)
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => fallback(),
                                    )
                                  : fallback(),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          preview.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
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
                        const SizedBox(height: 10),
                        Text(
                          timeRange,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: OnesColors.black,
                          ),
                        ),
                        if (preview.objective.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            preview.objective.trim(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: OnesColors.black.withOpacity(0.75),
                            ),
                          ),
                        ],
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OnesColors.purpleMid,
                            foregroundColor: OnesColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: _accepting
                              ? null
                              : () async {
                                  setState(() {
                                    _accepting = true;
                                  });
                                  try {
                                    final authController =
                                        context.read<AuthController>();
                                    final token = authController.idToken;
                                    if (!authController.isSignedIn ||
                                        token == null ||
                                        token.isEmpty) {
                                      final step =
                                          await authController.signInExisting();
                                      if (!context.mounted) return;
                                      if (step ==
                                          AuthNextStep.needsRegistration) {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const RegisterPage(
                                              popToRootOnComplete: false,
                                            ),
                                          ),
                                        );
                                      }
                                    } else if (!authController.isRegistered) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterPage(
                                            popToRootOnComplete: false,
                                          ),
                                        ),
                                      );
                                    }

                                    if (!context.mounted) return;
                                    final afterAuth =
                                        context.read<AuthController>();
                                    if (!afterAuth.isRegistered) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Sign in required to accept invitation.'),
                                        ),
                                      );
                                      setState(() {
                                        _accepting = false;
                                      });
                                      return;
                                    }

                                    final repo =
                                        context.read<EventsRepository>();
                                    if (repo is EventsApiRepository) {
                                      repo.setIdToken(afterAuth.idToken);
                                    }

                                    await context
                                        .read<EventsRepository>()
                                        .acceptInviteLink(
                                            preview.id, widget.sig);
                                    if (!context.mounted) return;

                                    Navigator.of(context).pushReplacementNamed(
                                      '${EventDetailPage.routeName}?eventId=${Uri.encodeComponent(preview.id)}&invitationStatus=accepted',
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;

                                    String message =
                                        'Failed to accept invitation.';
                                    if (e is DioException) {
                                      final status = e.response?.statusCode;
                                      final data = e.response?.data;
                                      String details = '';
                                      if (data is Map) {
                                        final code =
                                            data['code'] ?? data['error'];
                                        final msg = data['message'];
                                        details =
                                            '${code ?? ''} ${msg ?? ''}'.trim();
                                      } else if (data is String &&
                                          data.trim().isNotEmpty) {
                                        details = data.trim();
                                      }

                                      message =
                                          'Failed to accept invitation (HTTP ${status ?? 'unknown'}${details.isNotEmpty ? ' - $details' : ''}).';
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                      ),
                                    );
                                    setState(() {
                                      _accepting = false;
                                    });
                                  }
                                },
                          child: Text(
                            auth.isRegistered
                                ? 'Accept invitation'
                                : 'Sign in to accept',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
