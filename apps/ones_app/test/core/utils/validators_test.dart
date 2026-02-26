import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/utils/validators.dart';

void main() {
  group('validators', () {
    test('looksLikeEmail returns true for valid-like emails', () {
      expect(looksLikeEmail('a@b.co'), true);
      expect(looksLikeEmail('test.user+1@example.com'), true);
    });

    test('looksLikeEmail returns false for invalid emails', () {
      expect(looksLikeEmail(''), false);
      expect(looksLikeEmail('abc'), false);
      expect(looksLikeEmail('@example.com'), false);
      expect(looksLikeEmail('a@'), false);
      expect(looksLikeEmail('a@b'), false);
    });
  });
}
