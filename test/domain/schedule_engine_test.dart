import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/data/models/models.dart';
import 'package:tabriz_metro/domain/schedule/holiday_calendar.dart';
import 'package:tabriz_metro/domain/schedule/schedule_engine.dart';

import '../helpers.dart';

void main() {
  late Timetable tt;
  late HolidayCalendar cal;
  late ScheduleEngine engine;

  setUpAll(() {
    tt = loadTimetable();
    cal = loadHolidays();
    engine = ScheduleEngine(tt, cal);
  });

  // 2026-10-24 is a Saturday (weekday schedule); 2026-10-30 a Friday.
  final saturday = DateTime(2026, 10, 24);
  final friday = DateTime(2026, 10, 30);

  group('holiday detection', () {
    test('Friday uses the holiday schedule', () {
      expect(friday.weekday, DateTime.friday);
      expect(cal.scheduleFor(friday), ScheduleType.holiday);
      expect(HolidayCalendar.fridaysOnly().isHoliday(friday), isTrue);
    });

    test('Saturday to Thursday use the weekday schedule', () {
      for (var d = 0; d < 6; d++) {
        final day = saturday.add(Duration(days: d));
        expect(cal.scheduleFor(day), ScheduleType.weekday, reason: '$day');
      }
    });

    test('official holidays use the holiday schedule', () {
      // 22 Bahman 1405 = 2027-02-11 (Thursday).
      final revolutionDay = DateTime(2027, 2, 11);
      expect(cal.holidayOn(revolutionDay)?.jalali, '1405/11/22');
      expect(cal.scheduleFor(revolutionDay), ScheduleType.holiday);
      // Nowruz 1405.
      expect(cal.isHoliday(DateTime(2026, 3, 21)), isTrue);
      expect(cal.needsReview, isTrue);
    });

    test('override wins over the calendar', () {
      expect(
        cal.scheduleFor(friday, override: ScheduleType.weekday),
        ScheduleType.weekday,
      );
      final forced = ScheduleEngine(tt, cal, override: ScheduleType.holiday);
      expect(forced.scheduleTypeFor(saturday), ScheduleType.holiday);
    });
  });

  group('next departures', () {
    test('finds the next train at Eyl Goli toward Noor', () {
      final now = saturday.add(const Duration(hours: 6, minutes: 3));
      final next = engine.nextDepartures(0, Direction.towardNoor, now);
      expect(next, hasLength(4));
      expect(
        next.first.time,
        saturday.add(const Duration(hours: 6, minutes: 10)),
      );
      expect(next.first.scheduleType, ScheduleType.weekday);
      expect(next.first.minutesFrom(now), 7);
      for (var i = 1; i < next.length; i++) {
        expect(next[i].time.isAfter(next[i - 1].time), isTrue);
      }
    });

    test('a train departing this minute is still next', () {
      final now = saturday.add(
        const Duration(hours: 5, minutes: 55, seconds: 30),
      );
      final next = engine.nextDeparture(0, Direction.towardNoor, now)!;
      expect(next.time, saturday.add(const Duration(hours: 5, minutes: 55)));
      expect(next.minutesFrom(now), 0);
    });

    test('after the last train rolls over to the next day', () {
      // Thursday night → next day is Friday (holiday schedule, starts 07:30).
      final thursday = DateTime(2026, 10, 29, 23, 0);
      final next = engine.nextDeparture(0, Direction.towardNoor, thursday)!;
      expect(next.serviceDay, DateTime(2026, 10, 30));
      expect(next.scheduleType, ScheduleType.holiday);
      expect(next.time, DateTime(2026, 10, 30, 7, 30));
      expect(engine.serviceEnded(0, Direction.towardNoor, thursday), isTrue);
    });

    test('Friday night rolls over to Saturday weekday schedule', () {
      final next = engine.nextDeparture(
        17,
        Direction.towardEylGoli,
        DateTime(2026, 10, 30, 22, 0),
      )!;
      expect(next.scheduleType, ScheduleType.weekday);
      expect(next.time, DateTime(2026, 10, 31, 6, 15));
    });

    test('terminal has no departures in the arriving direction', () {
      expect(engine.nextDeparture(17, Direction.towardNoor, saturday), isNull);
      expect(
        engine.dayDepartures(0, Direction.towardEylGoli, saturday),
        isEmpty,
      );
      expect(
        engine.serviceWindow(17, Direction.towardNoor, ScheduleType.weekday),
        isNull,
      );
    });

    test('departure exposes times at other stations of the same train', () {
      final dep = engine.nextDeparture(
        0,
        Direction.towardNoor,
        saturday.add(const Duration(hours: 6)),
      )!;
      expect(dep.timeAt(17).difference(dep.time).inMinutes, 35);
    });

    test('service window and last departure', () {
      final w = engine.serviceWindow(
        0,
        Direction.towardNoor,
        ScheduleType.weekday,
      )!;
      expect(w.first, 5 * 60 + 55);
      expect(w.last, 20 * 60 + 40);
      expect(w.count, 60);
      final last = engine.lastDepartureOn(0, Direction.towardNoor, saturday)!;
      expect(last.time, DateTime(2026, 10, 24, 20, 40));
      expect(
        engine.lastDepartureOn(17, Direction.towardNoor, saturday),
        isNull,
      );
    });
  });

  group('train positions', () {
    test('estimates trains between stations', () {
      final now = DateTime(2026, 10, 24, 6, 0, 30);
      final pos = engine.trainPositions(Direction.towardNoor, now);
      // 05:55 train left Eyl Goli at 05:55 → at 06:00:30 between 2 and 3.
      final first = pos.firstWhere((p) => p.tripIndex == 0);
      expect(first.fromIndex, 2);
      expect(first.toIndex, 3);
      expect(first.progress, closeTo(0.75, 0.01));
    });

    test('reverse direction counts down station indices', () {
      final now = DateTime(2026, 10, 24, 6, 16);
      final pos = engine.trainPositions(Direction.towardEylGoli, now);
      expect(pos, hasLength(1));
      expect(pos.single.fromIndex, 17);
      expect(pos.single.toIndex, 16);
    });

    test('no trains at night', () {
      expect(
        engine.trainPositions(Direction.towardNoor, DateTime(2026, 10, 24, 2)),
        isEmpty,
      );
    });
  });
}
