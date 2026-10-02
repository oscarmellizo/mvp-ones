/// Rango de fechas de los atajos de "Cuándo" al crear un evento.
/// `end` nulo: se usa la duración por defecto del formulario.
class QuickEventRange {
  final DateTime start;
  final DateTime? end;

  const QuickEventRange(this.start, [this.end]);
}

class QuickEventRanges {
  const QuickEventRanges._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

  static QuickEventRange _wholeDays(DateTime first, DateTime last) =>
      QuickEventRange(_day(first), _endOfDay(last));

  /// Hoy de 00:00 a 23:59.
  static QuickEventRange today(DateTime now) => _wholeDays(now, now);

  /// Mañana de 00:00 a 23:59.
  static QuickEventRange tomorrow(DateTime now) {
    final t = DateTime(now.year, now.month, now.day + 1);
    return _wholeDays(t, t);
  }

  /// Sábado 00:00 a domingo 23:59 (sin festivos). Un sábado empieza hoy; un domingo es solo hoy.
  static QuickEventRange thisWeekend(DateTime now) {
    if (now.weekday == DateTime.sunday) return _wholeDays(now, now);
    final sat = DateTime(now.year, now.month, now.day + (DateTime.saturday - now.weekday));
    final sun = DateTime(sat.year, sat.month, sat.day + 1);
    return _wholeDays(sat, sun);
  }

  /// Empieza ahora (al minuto) y dura 30 minutos.
  static QuickEventRange now(DateTime now) {
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return QuickEventRange(start, start.add(const Duration(minutes: 30)));
  }

  /// Empieza dentro de 30 minutos.
  static QuickEventRange plus30(DateTime now) =>
      QuickEventRange(now.add(const Duration(minutes: 30)));

  /// Hoy de 19:00 a 23:59.
  static QuickEventRange evening(DateTime now) =>
      QuickEventRange(DateTime(now.year, now.month, now.day, 19), _endOfDay(now));
}
