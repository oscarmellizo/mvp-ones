import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/utils/datetime_formatters.dart';

void main() {
  group('datetime_formatters', () {
    test('formatMonthDayYear formats as "Month d, yyyy"', () {
      final dt = DateTime(2025, 2, 1);
      expect(formatMonthDayYear(dt), 'February 1, 2025');
    });

    test('formatTimeOfDay formats as h:mm AM/PM', () {
      expect(formatTimeOfDay(DateTime(2025, 1, 1, 0, 5)), '12:05 AM');
      expect(formatTimeOfDay(DateTime(2025, 1, 1, 12, 0)), '12:00 PM');
      expect(formatTimeOfDay(DateTime(2025, 1, 1, 15, 9)), '3:09 PM');
    });

    test('formatShortDate formats as mm/dd/yyyy', () {
      final dt = DateTime(2025, 12, 9);
      expect(formatShortDate(dt), '12/09/2025');
    });

    test('formatShortMonthDay formats as mm/dd', () {
      final dt = DateTime(2025, 12, 9);
      expect(formatShortMonthDay(dt), '12/09');
    });
  });
}
