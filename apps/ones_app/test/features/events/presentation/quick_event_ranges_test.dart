import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/presentation/quick_event_ranges.dart';

void main() {
  // Miércoles 2026-10-07 15:12.
  final wed = DateTime(2026, 10, 7, 15, 12);

  test('Hoy: hoy 00:00 a 23:59', () {
    final r = QuickEventRanges.today(wed);
    expect(r.start, DateTime(2026, 10, 7, 0, 0));
    expect(r.end, DateTime(2026, 10, 7, 23, 59));
  });

  test('Mañana: mañana 00:00 a 23:59', () {
    final r = QuickEventRanges.tomorrow(wed);
    expect(r.start, DateTime(2026, 10, 8, 0, 0));
    expect(r.end, DateTime(2026, 10, 8, 23, 59));
  });

  test('Mañana cruza de mes', () {
    final r = QuickEventRanges.tomorrow(DateTime(2026, 10, 31, 22, 0));
    expect(r.start, DateTime(2026, 11, 1, 0, 0));
  });

  test('Este fin de semana desde un día de semana: sábado 00:00 a domingo 23:59', () {
    final r = QuickEventRanges.thisWeekend(wed);
    expect(r.start, DateTime(2026, 10, 10, 0, 0));
    expect(r.end, DateTime(2026, 10, 11, 23, 59));
  });

  test('Este fin de semana un sábado: hoy sábado a domingo', () {
    final r = QuickEventRanges.thisWeekend(DateTime(2026, 10, 10, 11, 0));
    expect(r.start, DateTime(2026, 10, 10, 0, 0));
    expect(r.end, DateTime(2026, 10, 11, 23, 59));
  });

  test('Este fin de semana un domingo: solo el domingo', () {
    final r = QuickEventRanges.thisWeekend(DateTime(2026, 10, 11, 9, 0));
    expect(r.start, DateTime(2026, 10, 11, 0, 0));
    expect(r.end, DateTime(2026, 10, 11, 23, 59));
  });

  test('+30: empieza dentro de 30 minutos', () {
    final r = QuickEventRanges.plus30(wed);
    expect(r.start, DateTime(2026, 10, 7, 15, 42));
  });

  test('+30 cerca de medianoche pasa al día siguiente', () {
    final r = QuickEventRanges.plus30(DateTime(2026, 10, 7, 23, 50));
    expect(r.start, DateTime(2026, 10, 8, 0, 20));
  });

  test('Noche: hoy 19:00 a 23:59', () {
    final r = QuickEventRanges.evening(wed);
    expect(r.start, DateTime(2026, 10, 7, 19, 0));
    expect(r.end, DateTime(2026, 10, 7, 23, 59));
  });

  test('Ahora: empieza ahora y termina en 30 minutos', () {
    final r = QuickEventRanges.now(DateTime(2026, 10, 7, 15, 12, 40));
    expect(r.start, DateTime(2026, 10, 7, 15, 12));
    expect(r.end, DateTime(2026, 10, 7, 15, 42));
  });
}
