/// Immutable timetable models. Pure Dart — no Flutter imports.
library;

/// Travel direction along Line 1.
enum Direction {
  /// From Eyl Goli (index 0) toward Noor (index 17).
  towardNoor('eyl-goli-to-noor'),

  /// From Noor (index 17) toward Eyl Goli (index 0).
  towardEylGoli('noor-to-eyl-goli');

  const Direction(this.id);

  final String id;

  static Direction fromId(String id) => Direction.values.firstWhere(
    (d) => d.id == id,
    orElse: () => throw FormatException('Unknown direction', id),
  );

  Direction get opposite => this == towardNoor ? towardEylGoli : towardNoor;

  /// +1 when station indices increase along the direction of travel.
  int get step => this == towardNoor ? 1 : -1;
}

/// Which printed timetable applies on a day.
enum ScheduleType {
  weekday('weekday'),
  holiday('holiday');

  const ScheduleType(this.id);

  final String id;

  static ScheduleType fromId(String id) => ScheduleType.values.firstWhere(
    (t) => t.id == id,
    orElse: () => throw FormatException('Unknown schedule type', id),
  );
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

class Station {
  const Station({
    required this.index,
    required this.id,
    required this.nameFa,
    required this.nameEn,
    this.isHub = false,
    this.location,
  });

  final int index;
  final String id;
  final String nameFa;
  final String nameEn;
  final bool isHub;

  /// Coordinates, when known (from `stations-geo.json`).
  final GeoPoint? location;

  Station withLocation(GeoPoint? location) => Station(
    index: index,
    id: id,
    nameFa: nameFa,
    nameEn: nameEn,
    isHub: isHub,
    location: location,
  );

  String name({required bool persian}) => persian ? nameFa : nameEn;

  @override
  String toString() => 'Station($index, $id)';
}

/// One train run: [minutes] holds the time (minutes since midnight) at which
/// the train is at each station, indexed by station index (not travel order).
class Trip {
  const Trip(this.minutes);

  final List<int> minutes;

  int at(int stationIndex) => minutes[stationIndex];
}

class DirectionSchedule {
  const DirectionSchedule({
    required this.direction,
    required this.trips,
    required this.firstDeparture,
    required this.lastDeparture,
  });

  final Direction direction;
  final List<Trip> trips;

  /// Minutes since midnight at the origin terminal.
  final int firstDeparture;
  final int lastDeparture;
}

class Schedule {
  const Schedule({
    required this.type,
    required this.labelFa,
    required this.headwayMinutes,
    required this.updatedAtJalali,
    required this.directions,
    this.notesFa = const [],
  });

  final ScheduleType type;
  final String labelFa;
  final int headwayMinutes;
  final String updatedAtJalali;
  final List<String> notesFa;
  final Map<Direction, DirectionSchedule> directions;

  DirectionSchedule operator [](Direction d) => directions[d]!;
}

class LineInfo {
  const LineInfo({
    required this.number,
    required this.nameFa,
    required this.nameEn,
    required this.operatorFa,
    required this.website,
    required this.tripDurationMinutes,
  });

  final int number;
  final String nameFa;
  final String nameEn;
  final String operatorFa;
  final String website;
  final int tripDurationMinutes;
}

/// The full Line 1 dataset.
class Timetable {
  Timetable({
    required this.schemaVersion,
    required this.line,
    required this.stations,
    required this.schedules,
    this.shape = const [],
  });

  final int schemaVersion;
  final LineInfo line;
  final List<Station> stations;
  final Map<ScheduleType, Schedule> schedules;

  /// Polyline of the line on the city map (may be empty).
  final List<GeoPoint> shape;

  Schedule operator [](ScheduleType t) => schedules[t]!;

  int get stationCount => stations.length;

  Station get southTerminal => stations.first;
  Station get northTerminal => stations.last;

  Station? stationById(String id) {
    for (final s in stations) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The terminal a train in [d] is heading to.
  Station terminalOf(Direction d) =>
      d == Direction.towardNoor ? northTerminal : southTerminal;

  /// True when no train departs from [stationIndex] in [d] (it is the end
  /// of the line in that direction).
  bool isEndOfLine(int stationIndex, Direction d) => d == Direction.towardNoor
      ? stationIndex == stations.length - 1
      : stationIndex == 0;

  /// Direction needed to travel from [from] to [to], or null if equal.
  Direction? directionBetween(int from, int to) {
    if (from == to) return null;
    return to > from ? Direction.towardNoor : Direction.towardEylGoli;
  }

  /// Short version label of the bundled data, e.g. "1404/06/31 · 1404/03/17".
  String get dataVersion =>
      schedules.values.map((s) => s.updatedAtJalali).join(' · ');
}
