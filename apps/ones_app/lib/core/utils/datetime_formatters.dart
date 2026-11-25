String formatMonthDayYear(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatTimeOfDay(DateTime dt) {
  final hour = dt.hour;
  final minute = dt.minute;
  final isPm = hour >= 12;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  final suffix = isPm ? 'PM' : 'AM';
  return '$h12:$mm $suffix';
}

String formatShortDate(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return '$mm/$dd/${dt.year}';
}

String formatShortMonthDay(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return '$mm/$dd';
}

const List<String> _monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre'
];

const List<String> _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];

bool _isSpanish(String lang) => lang.toLowerCase().startsWith('es');

/// Full localized date: "12 de diciembre de 2026" / "December 12, 2026".
String formatDateLocalized(DateTime dt, String lang) {
  if (_isSpanish(lang)) {
    return '${dt.day} de ${_monthsEs[dt.month - 1]} de ${dt.year}';
  }
  return '${_monthsEn[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Short localized date: es → "12/12", en → "12/12" (MM/dd vs dd/MM).
String formatShortDateLocalized(DateTime dt, String lang) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return _isSpanish(lang) ? '$dd/$mm' : '$mm/$dd';
}

/// Localized time of day: es → 24h "20:30", en → 12h "8:30 PM".
String formatTimeOfDayLocalized(DateTime dt, String lang) {
  if (_isSpanish(lang)) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  return formatTimeOfDay(dt);
}

/// Localized event date range on one line.
String formatEventDateRangeLocalized(
  DateTime start,
  DateTime end,
  String lang,
) {
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) return formatDateLocalized(start, lang);
  return '${formatShortDateLocalized(start, lang)}'
      '–${formatShortDateLocalized(end, lang)} ${end.year}';
}
