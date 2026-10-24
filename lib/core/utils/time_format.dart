/// Time and date helpers that do not depend on Flutter.
library;

import 'persian.dart';

/// Parses "HH:MM" into minutes since midnight.
int parseHhMm(String hhmm) {
  final parts = toLatinDigits(hhmm).trim().split(':');
  if (parts.length != 2) {
    throw FormatException('Expected HH:MM', hhmm);
  }
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  if (h < 0 || h > 30 || m < 0 || m > 59) {
    throw FormatException('Out of range time', hhmm);
  }
  return h * 60 + m;
}

/// Formats minutes since midnight as "HH:MM" (wraps past 24h).
String formatMinutes(int minutes, {bool persian = false}) {
  final m = minutes % (24 * 60);
  final s =
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  return localizeDigits(s, persian: persian);
}

/// Formats the wall-clock time of [t] as "HH:MM".
String formatClock(DateTime t, {bool persian = false}) =>
    formatMinutes(t.hour * 60 + t.minute, persian: persian);

/// Minutes since local midnight of [t].
int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

/// Local midnight of [t]'s calendar day.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// A Jalali (Solar Hijri) date.
class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Converts a Gregorian date to Jalali (algorithm by Kazimierz M. Borkowski,
  /// as popularised by the jalaali-js library).
  factory JalaliDate.fromGregorian(DateTime g) {
    final gy = g.year, gm = g.month, gd = g.day;
    const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    final gy2 = gm > 2 ? gy + 1 : gy;
    var days =
        355666 +
        365 * gy +
        (gy2 + 3) ~/ 4 -
        (gy2 + 99) ~/ 100 +
        (gy2 + 399) ~/ 400 +
        gd +
        gdm[gm - 1];
    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final int jm;
    final int jd;
    if (days < 186) {
      jm = 1 + days ~/ 31;
      jd = 1 + days % 31;
    } else {
      jm = 7 + (days - 186) ~/ 30;
      jd = 1 + (days - 186) % 30;
    }
    return JalaliDate(jy, jm, jd);
  }

  static const monthNamesFa = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  String get monthNameFa => monthNamesFa[month - 1];

  @override
  String toString() =>
      '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is JalaliDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
