import '../../core/utils/time_format.dart';
import '../../data/models/models.dart';
import '../schedule/schedule_engine.dart';
import '../trip/trip_planner.dart';

/// A local notification to schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String? payload;

  @override
  String toString() => 'PlannedReminder($id @ $when: $title)';
}

/// Localized notification texts (implemented by the UI layer).
abstract interface class ReminderTexts {
  String leaveNowTitle();
  String leaveNowBody(String station, String time);
  String lastTrainTitle();
  String lastTrainBody(String station, String times);
  String commuteTitle(String from, String to);
  String commuteBody(String time, String arrival);
  String destinationTitle(String station);
  String destinationBody(String time);
  String stationName(Station s);
  String clock(DateTime t);
}

/// Notification id blocks per automation (each has room for 100 ids).
abstract final class ReminderIds {
  static const leaveNow = 1000;
  static const lastTrain = 2000;
  static const commute = 3000;
  static const destination = 4000;
  static const blockSize = 100;
}

const int lastTrainLeadMinutes = 30;
const int leaveNowSlackMinutes = 2;

List<DateTime> _days(DateTime now, int count) => [
  for (var i = 0; i < count; i++) DateTime(now.year, now.month, now.day + i),
];

DateTime _atTime(DateTime day, String hhmm) =>
    DateTime(day.year, day.month, day.day, 0, parseHhMm(hhmm));

/// "Leave now": for each of the next [days] days, the first train at
/// [station] in [direction] at/after [time]; notify [walkMinutes] (+ slack)
/// before it.
List<PlannedReminder> planLeaveNow({
  required ScheduleEngine engine,
  required ReminderTexts texts,
  required DateTime now,
  required Station station,
  required Direction direction,
  required String time,
  required int walkMinutes,
  int days = 7,
}) {
  final out = <PlannedReminder>[];
  for (final (i, day) in _days(now, days).indexed) {
    final target = _atTime(day, time);
    Departure? dep;
    for (final d in engine.dayDepartures(station.index, direction, day)) {
      if (!d.time.isBefore(target)) {
        dep = d;
        break;
      }
    }
    if (dep == null) continue;
    final fire = dep.time.subtract(
      Duration(minutes: walkMinutes + leaveNowSlackMinutes),
    );
    if (!fire.isAfter(now)) continue;
    out.add(
      PlannedReminder(
        id: ReminderIds.leaveNow + i,
        when: fire,
        title: texts.leaveNowTitle(),
        body: texts.leaveNowBody(
          texts.stationName(station),
          texts.clock(dep.time),
        ),
        payload: 'station:${station.id}',
      ),
    );
  }
  return out;
}

/// Last train: [lastTrainLeadMinutes] before the earliest "last train" of
/// the day at [station] (over both directions).
List<PlannedReminder> planLastTrain({
  required ScheduleEngine engine,
  required ReminderTexts texts,
  required DateTime now,
  required Station station,
  int days = 7,
}) {
  final out = <PlannedReminder>[];
  for (final (i, day) in _days(now, days).indexed) {
    final lasts = <Departure>[
      for (final d in Direction.values)
        ?engine.lastDepartureOn(station.index, d, day),
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (lasts.isEmpty) continue;
    final fire = lasts.first.time.subtract(
      const Duration(minutes: lastTrainLeadMinutes),
    );
    if (!fire.isAfter(now)) continue;
    final times = lasts
        .map(
          (d) =>
              '${texts.stationName(engine.timetable.terminalOf(d.direction))} '
              '${texts.clock(d.time)}',
        )
        .join(' · ');
    out.add(
      PlannedReminder(
        id: ReminderIds.lastTrain + i,
        when: fire,
        title: texts.lastTrainTitle(),
        body: texts.lastTrainBody(texts.stationName(station), times),
        payload: 'station:${station.id}',
      ),
    );
  }
  return out;
}

/// Commute: at [time] on workdays (days using the weekday timetable),
/// show the next train from [home] to [work].
List<PlannedReminder> planCommute({
  required ScheduleEngine engine,
  required ReminderTexts texts,
  required DateTime now,
  required Station home,
  required Station work,
  required String time,
  int days = 7,
}) {
  if (home.index == work.index) return const [];
  final out = <PlannedReminder>[];
  for (final (i, day) in _days(now, days).indexed) {
    if (engine.calendar.isHoliday(day)) continue;
    final fire = _atTime(day, time);
    if (!fire.isAfter(now)) continue;
    final plan = planTrip(
      engine: engine,
      origin: home,
      destination: work,
      now: fire,
    );
    if (plan == null || plan.boardAt.day != fire.day) continue;
    out.add(
      PlannedReminder(
        id: ReminderIds.commute + i,
        when: fire,
        title: texts.commuteTitle(
          texts.stationName(home),
          texts.stationName(work),
        ),
        body: texts.commuteBody(
          texts.clock(plan.boardAt),
          texts.clock(plan.arrival),
        ),
        payload: 'trip:${home.id}:${work.id}',
      ),
    );
  }
  return out;
}

/// Destination alert: when the train reaches the stop before the
/// destination.
PlannedReminder? planDestinationAlert({
  required TripPlan plan,
  required ReminderTexts texts,
  required DateTime now,
}) {
  if (plan.stops.length < 2) return null;
  final before = plan.penultimateStop;
  final fire = plan.stopCount == 1 ? plan.boardAt : before.time;
  if (!fire.isAfter(now)) return null;
  return PlannedReminder(
    id: ReminderIds.destination,
    when: fire,
    title: texts.destinationTitle(texts.stationName(plan.destination)),
    body: texts.destinationBody(texts.clock(plan.arrival)),
    payload: 'station:${plan.destination.id}',
  );
}
