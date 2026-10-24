import 'dart:convert';

import '../../core/utils/time_format.dart';
import '../../data/models/models.dart';

class Holiday {
  const Holiday({
    required this.date,
    required this.jalali,
    required this.nameFa,
    required this.nameEn,
  });

  final DateTime date;
  final String jalali;
  final String nameFa;
  final String nameEn;
}

/// Decides which timetable applies on a given day: Fridays and official
/// holidays use the holiday schedule, every other day the weekday one.
class HolidayCalendar {
  HolidayCalendar(Iterable<Holiday> holidays, {this.needsReview = false})
    : _byDate = {for (final h in holidays) _key(h.date): h};

  /// A calendar that knows only about Fridays.
  HolidayCalendar.fridaysOnly() : _byDate = const {}, needsReview = false;

  factory HolidayCalendar.fromJson(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final list = root['holidays'] as List<dynamic>? ?? const [];
    return HolidayCalendar([
      for (final h in list.cast<Map<String, dynamic>>())
        Holiday(
          date: DateTime.parse(h['date'] as String),
          jalali: h['jalali'] as String? ?? '',
          nameFa: h['nameFa'] as String? ?? '',
          nameEn: h['nameEn'] as String? ?? '',
        ),
    ], needsReview: root['needsReview'] as bool? ?? false);
  }

  final Map<int, Holiday> _byDate;

  /// True when the bundled list is marked as unverified.
  final bool needsReview;

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Iterable<Holiday> get holidays => _byDate.values;

  /// The official holiday on [day], if any.
  Holiday? holidayOn(DateTime day) => _byDate[_key(day)];

  bool isHoliday(DateTime day) =>
      day.weekday == DateTime.friday || _byDate.containsKey(_key(day));

  /// Schedule for [day]; [override] wins when not null (user setting).
  ScheduleType scheduleFor(DateTime day, {ScheduleType? override}) =>
      override ??
      (isHoliday(dateOnly(day)) ? ScheduleType.holiday : ScheduleType.weekday);
}
