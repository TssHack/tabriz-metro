import '../../data/models/models.dart';
import '../geo/geo.dart';
import '../schedule/schedule_engine.dart';

/// One station on a planned ride with its estimated time.
class TripStop {
  const TripStop(this.station, this.time);

  final Station station;
  final DateTime time;
}

/// An estimated journey. All times are estimates from the printed timetable.
class TripPlan {
  const TripPlan({
    required this.origin,
    required this.destination,
    required this.direction,
    required this.startAt,
    required this.walkMinutes,
    required this.walkMeters,
    required this.departure,
    required this.stops,
  });

  final Station origin;
  final Station destination;
  final Direction direction;

  /// When the rider starts (leaves home, or is at the platform).
  final DateTime startAt;

  /// Minutes to walk to [origin]; 0 when already at the station.
  final int walkMinutes;
  final double? walkMeters;

  /// The train the rider can catch.
  final Departure departure;

  /// Every station of the ride from origin to destination, inclusive.
  final List<TripStop> stops;

  DateTime get arriveAtOrigin => startAt.add(Duration(minutes: walkMinutes));
  DateTime get boardAt => departure.time;
  DateTime get arrival => stops.last.time;

  Duration get wait => boardAt.difference(arriveAtOrigin).isNegative
      ? Duration.zero
      : boardAt.difference(arriveAtOrigin);
  Duration get ride => arrival.difference(boardAt);
  Duration get total => arrival.difference(startAt);

  /// Number of stops travelled (stations after the origin).
  int get stopCount => stops.length - 1;

  /// The stop just before the destination (for "get ready" alerts).
  TripStop get penultimateStop => stops[stops.length - 2];
}

/// Plans a ride from [origin] to [destination] starting at [now].
///
/// When [walkMeters] is given (the rider is not yet at the station), the
/// walking time at [speed] is added before the earliest catchable train.
/// Returns null when origin == destination or no train is found.
TripPlan? planTrip({
  required ScheduleEngine engine,
  required Station origin,
  required Station destination,
  required DateTime now,
  double? walkMeters,
  WalkingSpeed speed = WalkingSpeed.normal,
}) {
  final direction = engine.timetable.directionBetween(
    origin.index,
    destination.index,
  );
  if (direction == null) return null;
  final walk = walkMeters == null ? 0 : walkMinutes(walkMeters, speed);
  final ready = now.add(Duration(minutes: walk));
  final dep = engine.nextDeparture(origin.index, direction, ready);
  if (dep == null) return null;
  final stations = engine.timetable.stations;
  final stops = <TripStop>[
    for (
      var i = origin.index;
      direction == Direction.towardNoor
          ? i <= destination.index
          : i >= destination.index;
      i += direction.step
    )
      TripStop(stations[i], dep.timeAt(i)),
  ];
  return TripPlan(
    origin: origin,
    destination: destination,
    direction: direction,
    startAt: now,
    walkMinutes: walk,
    walkMeters: walkMeters,
    departure: dep,
    stops: stops,
  );
}
