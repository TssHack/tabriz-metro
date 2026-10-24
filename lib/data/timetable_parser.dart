/// JSON parsing for the bundled data files. Pure Dart.
library;

import 'dart:convert';

import '../core/utils/time_format.dart';
import 'models/models.dart';

/// Thrown when the timetable JSON is structurally invalid.
class TimetableFormatException implements Exception {
  TimetableFormatException(this.message);

  final String message;

  @override
  String toString() => 'TimetableFormatException: $message';
}

/// Parses `tabriz-metro-line1-schedules.json` and, optionally,
/// `stations-geo.json`, validating the invariants the app relies on.
Timetable parseTimetable(String scheduleJson, {String? geoJson}) {
  final root = jsonDecode(scheduleJson) as Map<String, dynamic>;
  final lineJson = root['line'] as Map<String, dynamic>;
  final line = LineInfo(
    number: lineJson['number'] as int,
    nameFa: lineJson['nameFa'] as String,
    nameEn: lineJson['nameEn'] as String,
    operatorFa: lineJson['operatorFa'] as String? ?? '',
    website: lineJson['website'] as String? ?? '',
    tripDurationMinutes: lineJson['tripDurationMinutes'] as int? ?? 0,
  );

  final geo = geoJson == null ? null : parseStationsGeo(geoJson);

  final stations = <Station>[];
  for (final (i, s) in (root['stations'] as List<dynamic>).indexed) {
    final m = s as Map<String, dynamic>;
    final index = m['index'] as int;
    if (index != i) {
      throw TimetableFormatException('Station $i has index $index');
    }
    final id = m['id'] as String;
    stations.add(
      Station(
        index: index,
        id: id,
        nameFa: m['nameFa'] as String,
        nameEn: m['nameEn'] as String,
        isHub: m['isHub'] as bool? ?? false,
        location: geo?.locations[id],
      ),
    );
  }
  final n = stations.length;

  final schedules = <ScheduleType, Schedule>{};
  final schedulesJson = root['schedules'] as Map<String, dynamic>;
  for (final entry in schedulesJson.entries) {
    final sj = entry.value as Map<String, dynamic>;
    final type = ScheduleType.fromId(entry.key);
    final dirs = <Direction, DirectionSchedule>{};
    for (final de in (sj['directions'] as Map<String, dynamic>).entries) {
      final direction = Direction.fromId(de.key);
      final dj = de.value as Map<String, dynamic>;
      final trips = <Trip>[];
      for (final (ti, t) in (dj['trips'] as List<dynamic>).indexed) {
        final times = (t as List<dynamic>)
            .map((e) => parseHhMm(e as String))
            .toList(growable: false);
        if (times.length != n) {
          throw TimetableFormatException(
            '${type.id}/${direction.id} trip $ti has ${times.length} times, '
            'expected $n',
          );
        }
        _checkMonotonic(times, direction, '${type.id}/${direction.id}#$ti');
        trips.add(Trip(times));
      }
      trips.sort(
        (a, b) =>
            a.at(_origin(direction, n)).compareTo(b.at(_origin(direction, n))),
      );
      dirs[direction] = DirectionSchedule(
        direction: direction,
        trips: trips,
        firstDeparture: parseHhMm(dj['firstDeparture'] as String),
        lastDeparture: parseHhMm(dj['lastDeparture'] as String),
      );
    }
    if (dirs.length != Direction.values.length) {
      throw TimetableFormatException('${type.id} is missing a direction');
    }
    schedules[type] = Schedule(
      type: type,
      labelFa: sj['labelFa'] as String? ?? '',
      headwayMinutes: sj['headwayMinutes'] as int,
      updatedAtJalali: sj['updatedAtJalali'] as String? ?? '',
      notesFa: [
        for (final note in (sj['notesFa'] as List<dynamic>? ?? const []))
          note as String,
      ],
      directions: dirs,
    );
  }
  if (schedules.length != ScheduleType.values.length) {
    throw TimetableFormatException('Missing schedule type');
  }

  return Timetable(
    schemaVersion: root['schemaVersion'] as int? ?? 1,
    line: line,
    stations: stations,
    schedules: schedules,
    shape: geo?.shape ?? const [],
  );
}

int _origin(Direction d, int n) => d == Direction.towardNoor ? 0 : n - 1;

void _checkMonotonic(List<int> times, Direction d, String label) {
  for (var i = 1; i < times.length; i++) {
    final ok = d == Direction.towardNoor
        ? times[i] > times[i - 1]
        : times[i] < times[i - 1];
    if (!ok) {
      throw TimetableFormatException('$label is not monotonic at station $i');
    }
  }
}

/// Parsed contents of `stations-geo.json`.
class StationsGeo {
  const StationsGeo({required this.locations, required this.shape});

  final Map<String, GeoPoint> locations;
  final List<GeoPoint> shape;
}

/// Parses `stations-geo.json`. Entries with missing coordinates are skipped,
/// so the map can degrade gracefully.
StationsGeo parseStationsGeo(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  final locations = <String, GeoPoint>{};
  for (final s in (root['stations'] as List<dynamic>? ?? const [])) {
    final m = s as Map<String, dynamic>;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    locations[m['id'] as String] = GeoPoint(lat, lng);
  }
  final shapeJson =
      (root['shape'] as Map<String, dynamic>?)?['points'] as List<dynamic>? ??
      const [];
  final shape = [
    for (final p in shapeJson)
      GeoPoint(
        ((p as List<dynamic>)[0] as num).toDouble(),
        (p[1] as num).toDouble(),
      ),
  ];
  return StationsGeo(locations: locations, shape: shape);
}
