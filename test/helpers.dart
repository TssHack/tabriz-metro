import 'dart:io';

import 'package:tabriz_metro/data/models/models.dart';
import 'package:tabriz_metro/data/timetable_parser.dart';
import 'package:tabriz_metro/domain/schedule/holiday_calendar.dart';

String readData(String name) => File('data/$name').readAsStringSync();

Timetable loadTimetable() => parseTimetable(
  readData('tabriz-metro-line1-schedules.json'),
  geoJson: readData('stations-geo.json'),
);

HolidayCalendar loadHolidays() =>
    HolidayCalendar.fromJson(readData('iran-holidays.json'));
