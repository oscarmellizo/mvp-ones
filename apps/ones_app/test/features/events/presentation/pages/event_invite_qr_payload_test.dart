import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/presentation/pages/event_invite_qr_payload.dart';

void main() {
  test('parses the signed event invite URL generated for event QR codes', () {
    final payload = EventInviteQrPayload.tryParse(
      'https://appdev.ones.events/event-invite'
      '?eventId=event-123&sig=signed-value',
    );

    expect(payload, isNotNull);
    expect(payload!.eventId, 'event-123');
    expect(payload.signature, 'signed-value');
  });

  test('rejects a QR without a complete event invite payload', () {
    expect(
      EventInviteQrPayload.tryParse(
        'https://appdev.ones.events/event-invite?eventId=event-123',
      ),
      isNull,
    );
    expect(
      EventInviteQrPayload.tryParse(
        'https://appdev.ones.events/other?eventId=event-123&sig=signed-value',
      ),
      isNull,
    );
  });
}
