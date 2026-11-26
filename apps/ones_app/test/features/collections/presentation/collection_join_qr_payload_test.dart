import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/collections/presentation/pages/collection_join_qr_payload.dart';

void main() {
  group('CollectionJoinQrPayload.tryParse', () {
    test('accepts the production web join URL', () {
      final payload = CollectionJoinQrPayload.tryParse(
        'https://app.ones.events/collections/join?collectionId=c-1&token=abc',
      );

      expect(payload?.collectionId, 'c-1');
      expect(payload?.token, 'abc');
    });

    test('accepts the app scheme join URL', () {
      final payload = CollectionJoinQrPayload.tryParse(
        'ones://collections/join?collectionId=c-1&token=abc',
      );

      expect(payload?.collectionId, 'c-1');
      expect(payload?.token, 'abc');
    });

    test('accepts a development web URL', () {
      final payload = CollectionJoinQrPayload.tryParse(
        'https://appdev.ones.events/collections/join?collectionId=c-1&token=abc',
      );
      expect(payload?.collectionId, 'c-1');
    });

    test('rejects an unexpected host and repeated credentials', () {
      expect(
        CollectionJoinQrPayload.tryParse(
          'https://example.com/collections/join?collectionId=c-1&token=abc',
        ),
        isNull,
      );
      expect(
        CollectionJoinQrPayload.tryParse(
          'https://app.ones.events/collections/join?collectionId=c-1&collectionId=c-2&token=abc',
        ),
        isNull,
      );
    });
  });
}
