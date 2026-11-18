import 'event_invite_link_page.dart';

class EventInviteQrPayload {
  final String eventId;
  final String signature;

  const EventInviteQrPayload({
    required this.eventId,
    required this.signature,
  });

  static EventInviteQrPayload? tryParse(String rawValue) {
    final uri = Uri.tryParse(rawValue.trim());
    if (uri == null || uri.path != EventInviteLinkPage.routeName) {
      return null;
    }

    final eventId = uri.queryParameters['eventId']?.trim();
    final signature = uri.queryParameters['sig']?.trim();
    if (eventId == null ||
        eventId.isEmpty ||
        signature == null ||
        signature.isEmpty) {
      return null;
    }

    return EventInviteQrPayload(
      eventId: eventId,
      signature: signature,
    );
  }
}
