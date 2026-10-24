import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/core/utils/time_format.dart';
import 'package:tabriz_metro/data/models/models.dart';
import 'package:tabriz_metro/domain/automation/reminders.dart';
import 'package:tabriz_metro/domain/schedule/schedule_engine.dart';
import 'package:tabriz_metro/domain/trip/trip_planner.dart';

import '../helpers.dart';

class _Texts implements ReminderTexts {
  @override
  String clock(DateTime t) => formatClock(t);
  @override
  String commuteBody(String time, String arrival) => '$time>$arrival';
  @override
  String commuteTitle(String from, String to) => '$from-$to';
  @override
  String destinationBody(String time) => 'arr $time';
  @override
  String destinationTitle(String station) => 'next $station';
  @override
  String lastTrainBody(String station, String times) => '$station: $times';
  @override
  String lastTrainTitle() => 'last';
  @override
  String leaveNowBody(String station, String time) => '$station $time';
  @override
  String leaveNowTitle() => 'leave';
  @override
  String stationName(Station s) => s.nameEn;
}

void main() {
  late Timetable tt;
  late ScheduleEngine engine;
  final texts = _Texts();
  // Saturday 2026-10-24 at 05:00.
  final now = DateTime(2026, 10, 24, 5);

  setUpAll(() {
    tt = loadTimetable();
    engine = ScheduleEngine(tt, loadHolidays());
  });

  test('leave-now fires walk + slack before the first train after time', () {
    final r = planLeaveNow(
      engine: engine,
      texts: texts,
      now: now,
      station: tt.stations[0],
      direction: Direction.towardNoor,
      time: '07:00',
      walkMinutes: 10,
    );
    expect(r, hasLength(7));
    // Saturday: train 07:10 → fire 06:58.
    expect(r.first.when, DateTime(2026, 10, 24, 6, 58));
    expect(r.first.body, 'Eyl Goli 07:10');
    expect(r.first.id, ReminderIds.leaveNow);
    expect(r.map((e) => e.id).toSet(), hasLength(7));
    // Friday 2026-10-30 uses the holiday timetable (first train 07:30).
    final friday = r.firstWhere((e) => e.when.day == 30);
    expect(friday.when, DateTime(2026, 10, 30, 7, 18));
  });

  test('leave-now skips reminders already in the past', () {
    final r = planLeaveNow(
      engine: engine,
      texts: texts,
      now: DateTime(2026, 10, 24, 8),
      station: tt.stations[0],
      direction: Direction.towardNoor,
      time: '07:00',
      walkMinutes: 10,
    );
    expect(r, hasLength(6));
    expect(r.first.when.day, 25);
  });

  test('last train fires 30 min before the earliest last train', () {
    final r = planLastTrain(
      engine: engine,
      texts: texts,
      now: now,
      station: tt.stations[0],
      days: 1,
    );
    expect(r, hasLength(1));
    // Eyl Goli: only toward Noor; last 20:40 → 20:10.
    expect(r.single.when, DateTime(2026, 10, 24, 20, 10));
    expect(r.single.body, contains('20:40'));
  });

  test('commute skips holidays and plans home → work', () {
    final r = planCommute(
      engine: engine,
      texts: texts,
      now: now,
      home: tt.stations[2],
      work: tt.stations[10],
      time: '07:15',
    );
    // 7 days from Saturday: Friday is skipped.
    expect(r, hasLength(6));
    expect(r.every((e) => e.when.weekday != DateTime.friday), isTrue);
    expect(r.first.title, "Emam Reza-Meydan-e Sa'at");
    expect(r.first.payload, 'trip:emam-reza:meydan-saat');
    expect(
      planCommute(
        engine: engine,
        texts: texts,
        now: now,
        home: tt.stations[2],
        work: tt.stations[2],
        time: '07:15',
      ),
      isEmpty,
    );
  });

  test('destination alert fires at the stop before the destination', () {
    final plan = planTrip(
      engine: engine,
      origin: tt.stations[0],
      destination: tt.stations[5],
      now: DateTime(2026, 10, 24, 7, 1),
    )!;
    final r = planDestinationAlert(
      plan: plan,
      texts: texts,
      now: plan.startAt,
    )!;
    expect(r.when, plan.stops[4].time);
    expect(r.title, 'next Ostad Shahriar');
    expect(r.id, ReminderIds.destination);
    expect(
      planDestinationAlert(plan: plan, texts: texts, now: plan.arrival),
      isNull,
    );
  });
}
