import 'package:flutter/services.dart';

import '../../app/providers.dart';
import '../../domain/schedule/holiday_calendar.dart';
import '../timetable_parser.dart';

const scheduleAsset = 'data/tabriz-metro-line1-schedules.json';
const stationsGeoAsset = 'data/stations-geo.json';
const holidaysAsset = 'data/iran-holidays.json';

/// Loads and parses the bundled timetable, coordinates and holiday list.
/// Missing optional files (coordinates, holidays) degrade gracefully.
Future<AppData> loadAppData([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final schedule = await b.loadString(scheduleAsset);
  String? geo;
  try {
    geo = await b.loadString(stationsGeoAsset);
  } on Object {
    geo = null;
  }
  HolidayCalendar holidays;
  try {
    holidays = HolidayCalendar.fromJson(await b.loadString(holidaysAsset));
  } on Object {
    holidays = HolidayCalendar.fridaysOnly();
  }
  return AppData(
    timetable: parseTimetable(schedule, geoJson: geo),
    holidays: holidays,
  );
}
