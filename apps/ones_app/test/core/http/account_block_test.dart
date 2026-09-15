import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/http/account_block.dart';

void main() {
  group('AccountBlock.codeFrom', () {
    test('returns ACCOUNT_DISABLED for a 403 carrying that code', () {
      expect(
        AccountBlock.codeFrom(403, {'code': 'ACCOUNT_DISABLED', 'status': 'DISABLED'}),
        'ACCOUNT_DISABLED',
      );
    });

    test('returns ACCOUNT_CLOSED for a 403 carrying that code', () {
      expect(AccountBlock.codeFrom(403, {'code': 'ACCOUNT_CLOSED'}), 'ACCOUNT_CLOSED');
    });

    test('ignores 403 responses with other codes', () {
      expect(AccountBlock.codeFrom(403, {'code': 'FORBIDDEN'}), isNull);
      expect(AccountBlock.codeFrom(403, {}), isNull);
      expect(AccountBlock.codeFrom(403, 'nope'), isNull);
      expect(AccountBlock.codeFrom(403, null), isNull);
    });

    test('ignores non-403 statuses even with the code', () {
      expect(AccountBlock.codeFrom(401, {'code': 'ACCOUNT_CLOSED'}), isNull);
      expect(AccountBlock.codeFrom(200, {'code': 'ACCOUNT_CLOSED'}), isNull);
      expect(AccountBlock.codeFrom(null, {'code': 'ACCOUNT_CLOSED'}), isNull);
    });
  });
}
