import '../../core/utils/time_format.dart';
import '../../data/models/models.dart';
import 'holiday_calendar.dart';

/// A concrete train passing a station on a specific service day.
class Departure {
  const Departure({
    required this.serviceDay,
    required this.stationIndex,
    required this.direction,
    required this.scheduleType,
    required this.tripIndex,
    required this.trip,
  });

  /// Local midnight of the day this run operates.
  final DateTime serviceDay;
  final int stationIndex;
  final Direction direction;
  final ScheduleType scheduleType;
  final int tripIndex;
  final Trip trip;

  /// Time at the queried station.
  DateTime get time => timeAt(stationIndex);

  /// Time this same train is at [index].
  DateTime timeAt(int index) => _at(serviceDay, trip.at(index));

  /// Whole minutes from [now] until this departure (never negative).
  int minutesFrom(DateTime now) {
    final diff = time.difference(_truncate(now)).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  @override
  String toString() =>
      'Departure(${direction.id} #$tripIndex @ $stationIndex ${formatClock(time)})';
}

/// Estimated position of a running train between two stations.
class TrainPosition {
  const TrainPosition({
    required this.tripIndex,
    required this.direction,
    required this.fromIndex,
    required this.toIndex,
    required this.progress,
  });

  final int tripIndex;
  final Direction direction;

  /// Last station passed (or the station the train is at).
  final int fromIndex;

  /// Next station the train will reach.
  final int toIndex;

  /// 0 = at [fromIndex], 1 = arriving at [toIndex].
  final double progress;
}

/// First/last train at a station for a schedule.
class ServiceWindow {
  const ServiceWindow(this.first, this.last, this.count);

  /// Minutes since midnight.
  final int first;
  final int last;
  final int count;
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

DateTime _truncate(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// Timetable queries. Pure Dart; all times are local wall-clock.
class ScheduleEngine {
  ScheduleEngine(this.timetable, this.calendar, {this.override});

  final Timetable timetable;
  final HolidayCalendar calendar;

  /// Forces a schedule type regardless of the date (user setting).
  final ScheduleType? override;

  ScheduleType scheduleTypeFor(DateTime day) =>
      calendar.scheduleFor(day, override: override);

  Schedule scheduleFor(DateTime day) => timetable[scheduleTypeFor(day)];

  /// All trains at [station] in [direction] on [day], in time order.
  List<Departure> dayDepartures(
    int station,
    Direction direction,
    DateTime day, {
    ScheduleType? type,
  }) {
    if (timetable.isEndOfLine(station, direction)) return const [];
    final service = dateOnly(day);
    final t = type ?? scheduleTypeFor(service);
    final trips = timetable[t][direction].trips;
    return [
      for (final (i, trip) in trips.indexed)
        Departure(
          serviceDay: service,
          stationIndex: station,
          direction: direction,
          scheduleType: t,
          tripIndex: i,
          trip: trip,
        ),
    ];
  }

  /// Departures at or after [from], rolling over to following days (each
  /// with its own weekday/holiday schedule) for up to [maxDays].
  Iterable<Departure> departuresFrom(
    int station,
    Direction direction,
    DateTime from, {
    int maxDays = 8,
  }) sync* {
    final start = _truncate(from);
    var day = dateOnly(from);
    for (var d = 0; d < maxDays; d++) {
      for (final dep in dayDepartures(station, direction, day)) {
        if (!dep.time.isBefore(start)) yield dep;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }

  List<Departure> nextDepartures(
    int station,
    Direction direction,
    DateTime now, {
    int count = 4,
  }) => departuresFrom(station, direction, now).take(count).toList();

  Departure? nextDeparture(int station, Direction direction, DateTime now) {
    for (final d in departuresFrom(station, direction, now)) {
      return d;
    }
    return null;
  }

  /// True when the last train of [day] at [station] has already left.
  bool serviceEnded(int station, Direction direction, DateTime now) {
    final today = dayDepartures(station, direction, now);
    return today.isNotEmpty && today.last.time.isBefore(_truncate(now));
  }

  ServiceWindow? serviceWindow(
    int station,
    Direction direction,
    ScheduleType type,
  ) {
    if (timetable.isEndOfLine(station, direction)) return null;
    final trips = timetable[type][direction].trips;
    if (trips.isEmpty) return null;
    return ServiceWindow(
      trips.first.at(station),
      trips.last.at(station),
      trips.length,
    );
  }

  /// The last train of the service day containing [now], or null if none.
  Departure? lastDepartureOn(int station, Direction direction, DateTime now) {
    final list = dayDepartures(station, direction, now);
    return list.isEmpty ? null : list.last;
  }

  /// Estimated positions of trains running in [direction] at [now], derived
  /// purely from the timetable.
  List<TrainPosition> trainPositions(Direction direction, DateTime now) {
    final day = dateOnly(now);
    final schedule = scheduleFor(day);
    final nowMin =
        now.difference(day).inSeconds / 60.0; // fractional minutes of day
    final n = timetable.stationCount;
    final order = direction == Direction.towardNoor
        ? List<int>.generate(n, (i) => i)
        : List<int>.generate(n, (i) => n - 1 - i);
    final result = <TrainPosition>[];
    for (final (ti, trip) in schedule[direction].trips.indexed) {
      final start = trip.at(order.first);
      final end = trip.at(order.last);
      if (nowMin < start || nowMin >= end) continue;
      for (var k = 0; k < order.length - 1; k++) {
        final a = trip.at(order[k]);
        final b = trip.at(order[k + 1]);
        if (nowMin >= a && nowMin < b) {
          result.add(
            TrainPosition(
              tripIndex: ti,
              direction: direction,
              fromIndex: order[k],
              toIndex: order[k + 1],
              progress: ((nowMin - a) / (b - a)).clamp(0.0, 1.0),
            ),
          );
          break;
        }
      }
    }
    return result;
  }
}
