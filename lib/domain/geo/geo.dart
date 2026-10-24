import 'dart:math' as math;

import '../../data/models/models.dart';

const double _earthRadiusMeters = 6371008.8;

/// Great-circle distance in meters between [a] and [b].
double haversineMeters(GeoPoint a, GeoPoint b) {
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Walking pace presets (meters per second).
enum WalkingSpeed {
  slow(0.95),
  normal(1.3),
  fast(1.65);

  const WalkingSpeed(this.metersPerSecond);

  final double metersPerSecond;

  static WalkingSpeed fromName(String? name) => WalkingSpeed.values.firstWhere(
    (s) => s.name == name,
    orElse: () => WalkingSpeed.normal,
  );
}

/// Streets are not straight lines: straight-line distance is scaled by this
/// factor to approximate walking distance.
const double walkingDetourFactor = 1.25;

/// Estimated whole minutes to walk [meters] (straight-line) at [speed].
int walkMinutes(double meters, WalkingSpeed speed) {
  if (meters <= 0) return 0;
  final seconds = meters * walkingDetourFactor / speed.metersPerSecond;
  return (seconds / 60).ceil();
}

class StationDistance {
  const StationDistance(this.station, this.meters);

  final Station station;
  final double meters;
}

/// Stations with known coordinates, sorted by distance from [from].
List<StationDistance> stationsByDistance(
  Iterable<Station> stations,
  GeoPoint from,
) {
  final list = [
    for (final s in stations)
      if (s.location != null)
        StationDistance(s, haversineMeters(from, s.location!)),
  ]..sort((a, b) => a.meters.compareTo(b.meters));
  return list;
}

/// Nearest station with known coordinates, or null if none have any.
StationDistance? nearestStation(Iterable<Station> stations, GeoPoint from) {
  final sorted = stationsByDistance(stations, from);
  return sorted.isEmpty ? null : sorted.first;
}
