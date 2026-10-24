import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/data/models/models.dart';
import 'package:tabriz_metro/domain/geo/geo.dart';
import 'package:tabriz_metro/domain/schedule/schedule_engine.dart';
import 'package:tabriz_metro/domain/trip/trip_planner.dart';

import '../helpers.dart';

void main() {
  late Timetable tt;
  late ScheduleEngine engine;

  setUpAll(() {
    tt = loadTimetable();
    engine = ScheduleEngine(tt, loadHolidays());
  });

  group('haversine', () {
    test('zero for identical points', () {
      const p = GeoPoint(38.07, 46.29);
      expect(haversineMeters(p, p), 0);
    });

    test('one degree of latitude is ~111 km', () {
      expect(
        haversineMeters(const GeoPoint(38, 46), const GeoPoint(39, 46)),
        closeTo(111195, 200),
      );
    });

    test('known pair: Tehran Azadi tower to Milad tower ≈ 6 km', () {
      final d = haversineMeters(
        const GeoPoint(35.6997, 51.3380),
        const GeoPoint(35.7448, 51.3753),
      );
      expect(d, closeTo(6000, 400));
    });

    test('is symmetric', () {
      const a = GeoPoint(38.02, 46.36);
      const b = GeoPoint(38.05, 46.23);
      expect(haversineMeters(a, b), closeTo(haversineMeters(b, a), 1e-6));
    });
  });

  group('nearest station', () {
    test('a point at a station returns that station', () {
      final saat = tt.stationById('meydan-saat')!;
      final n = nearestStation(tt.stations, saat.location!)!;
      expect(n.station.id, 'meydan-saat');
      expect(n.meters, lessThan(1));
    });

    test('sorts by distance and skips stations without coordinates', () {
      final stations = [
        const Station(
          index: 0,
          id: 'a',
          nameFa: 'a',
          nameEn: 'a',
          location: GeoPoint(0, 0.02),
        ),
        const Station(index: 1, id: 'b', nameFa: 'b', nameEn: 'b'),
        const Station(
          index: 2,
          id: 'c',
          nameFa: 'c',
          nameEn: 'c',
          location: GeoPoint(0, 0.01),
        ),
      ];
      final sorted = stationsByDistance(stations, const GeoPoint(0, 0));
      expect(sorted.map((s) => s.station.id), ['c', 'a']);
      expect(nearestStation(const [], const GeoPoint(0, 0)), isNull);
    });
  });

  group('walking', () {
    test('minutes scale with speed', () {
      expect(walkMinutes(0, WalkingSpeed.normal), 0);
      final slow = walkMinutes(1000, WalkingSpeed.slow);
      final normal = walkMinutes(1000, WalkingSpeed.normal);
      final fast = walkMinutes(1000, WalkingSpeed.fast);
      expect(slow, greaterThan(normal));
      expect(normal, greaterThan(fast));
      // 1000 m × 1.25 / 1.3 m/s = 961 s → 17 min.
      expect(normal, 17);
    });

    test('fromName falls back to normal', () {
      expect(WalkingSpeed.fromName('fast'), WalkingSpeed.fast);
      expect(WalkingSpeed.fromName('bogus'), WalkingSpeed.normal);
      expect(WalkingSpeed.fromName(null), WalkingSpeed.normal);
    });
  });

  group('trip planner', () {
    final morning = DateTime(2026, 10, 24, 7, 1); // Saturday

    test('plans a ride from the station with no walk', () {
      final plan = planTrip(
        engine: engine,
        origin: tt.stations[0],
        destination: tt.stations[17],
        now: morning,
      )!;
      expect(plan.direction, Direction.towardNoor);
      expect(plan.walkMinutes, 0);
      expect(plan.boardAt, DateTime(2026, 10, 24, 7, 10));
      expect(plan.arrival, DateTime(2026, 10, 24, 7, 45));
      expect(plan.ride.inMinutes, 35);
      expect(plan.stopCount, 17);
      expect(plan.stops.first.station.id, 'eyl-goli');
      expect(plan.stops.last.station.id, 'noor');
      expect(plan.penultimateStop.station.id, 'shahid-bakri');
      expect(plan.wait.inMinutes, 9);
      expect(plan.total.inMinutes, 44);
    });

    test('walking time pushes to a later train', () {
      final plan = planTrip(
        engine: engine,
        origin: tt.stations[0],
        destination: tt.stations[5],
        now: morning,
        walkMeters: 1000, // 17 min at normal pace → ready 07:18
      )!;
      expect(plan.walkMinutes, 17);
      expect(plan.arriveAtOrigin, DateTime(2026, 10, 24, 7, 18));
      expect(plan.boardAt, DateTime(2026, 10, 24, 7, 25));
      expect(plan.stopCount, 5);
    });

    test('reverse direction ride lists stations in travel order', () {
      final plan = planTrip(
        engine: engine,
        origin: tt.stations[12],
        destination: tt.stations[8],
        now: morning,
      )!;
      expect(plan.direction, Direction.towardEylGoli);
      expect(plan.stops.map((s) => s.station.index), [12, 11, 10, 9, 8]);
      for (var i = 1; i < plan.stops.length; i++) {
        expect(plan.stops[i].time.isAfter(plan.stops[i - 1].time), isTrue);
      }
    });

    test('late night plans the first train of the next day', () {
      final plan = planTrip(
        engine: engine,
        origin: tt.stations[3],
        destination: tt.stations[10],
        now: DateTime(2026, 10, 24, 23, 30),
      )!;
      expect(plan.boardAt.day, 25);
    });

    test('same origin and destination returns null', () {
      expect(
        planTrip(
          engine: engine,
          origin: tt.stations[4],
          destination: tt.stations[4],
          now: morning,
        ),
        isNull,
      );
    });
  });
}
