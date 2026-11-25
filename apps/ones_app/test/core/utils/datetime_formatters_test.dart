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

    test('formatDateLocalized localizes months per language', () {
      final dt = DateTime(2026, 12, 12);
      expect(formatDateLocalized(dt, 'es'), '12 de diciembre de 2026');
      expect(formatDateLocalized(dt, 'en'), 'December 12, 2026');
    });

    test('formatShortDateLocalized swaps day/month per language', () {
      final dt = DateTime(2026, 3, 9);
      expect(formatShortDateLocalized(dt, 'es'), '09/03');
      expect(formatShortDateLocalized(dt, 'en'), '03/09');
    });

    test('formatTimeOfDayLocalized uses 24h for es and 12h for en', () {
      final dt = DateTime(2026, 1, 1, 20, 30);
      expect(formatTimeOfDayLocalized(dt, 'es'), '20:30');
      expect(formatTimeOfDayLocalized(dt, 'en'), '8:30 PM');
    });

    test('formatEventDateRangeLocalized handles same-day and multi-day', () {
      final same = DateTime(2026, 12, 12);
      expect(
        formatEventDateRangeLocalized(same, same, 'es'),
        '12 de diciembre de 2026',
      );
      expect(
        formatEventDateRangeLocalized(
          DateTime(2026, 12, 12),
          DateTime(2026, 12, 13),
          'es',
        ),
        '12/12–13/12 2026',
      );
      expect(
        formatEventDateRangeLocalized(
          DateTime(2026, 12, 12),
          DateTime(2026, 12, 13),
          'en',
        ),
        '12/12–12/13 2026',
      );
    });
  });
}
