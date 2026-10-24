import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/data/models/models.dart';
import 'package:tabriz_metro/data/timetable_parser.dart';

import '../helpers.dart';

void main() {
  late Timetable tt;

  setUpAll(() => tt = loadTimetable());

  test('parses 18 stations in route order', () {
    expect(tt.stationCount, 18);
    expect(tt.stations.first.id, 'eyl-goli');
    expect(tt.stations.last.id, 'noor');
    for (final (i, s) in tt.stations.indexed) {
      expect(s.index, i);
    }
    expect(tt.stations.where((s) => s.isHub).map((s) => s.id), ['salar-melli']);
  });

  test('every trip has 18 times and is monotonic per direction', () {
    for (final schedule in tt.schedules.values) {
      for (final ds in schedule.directions.values) {
        expect(ds.trips, isNotEmpty);
        for (final trip in ds.trips) {
          expect(trip.minutes, hasLength(18));
          for (var i = 1; i < 18; i++) {
            if (ds.direction == Direction.towardNoor) {
              expect(trip.at(i), greaterThan(trip.at(i - 1)));
            } else {
              expect(trip.at(i), lessThan(trip.at(i - 1)));
            }
          }
        }
      }
    }
  });

  test('trip counts, headways and first/last match the README', () {
    final wd = tt[ScheduleType.weekday];
    final hd = tt[ScheduleType.holiday];
    expect(wd.headwayMinutes, 15);
    expect(hd.headwayMinutes, 16);
    expect(wd[Direction.towardNoor].trips, hasLength(60));
    expect(wd[Direction.towardEylGoli].trips, hasLength(61));
    expect(hd[Direction.towardNoor].trips, hasLength(49));
    expect(hd[Direction.towardEylGoli].trips, hasLength(50));
    expect(wd[Direction.towardNoor].trips.first.at(0), 5 * 60 + 55);
    expect(wd[Direction.towardNoor].trips.last.at(0), 20 * 60 + 40);
    expect(wd[Direction.towardEylGoli].trips.first.at(17), 6 * 60 + 15);
    expect(wd[Direction.towardEylGoli].trips.last.at(17), 21 * 60 + 15);
  });

  test('trips are sorted by departure from origin', () {
    for (final s in tt.schedules.values) {
      final up = s[Direction.towardNoor].trips;
      for (var i = 1; i < up.length; i++) {
        expect(up[i].at(0), greaterThan(up[i - 1].at(0)));
      }
    }
  });

  test('merges coordinates from stations-geo.json', () {
    expect(tt.stations.every((s) => s.location != null), isTrue);
    expect(tt.shape.length, greaterThan(10));
    final eg = tt.stationById('eyl-goli')!.location!;
    expect(eg.lat, closeTo(38.02, 0.05));
    expect(eg.lng, closeTo(46.36, 0.05));
  });

  test('geo entries without coordinates are skipped', () {
    final geo = parseStationsGeo(
      jsonEncode({
        'stations': [
          {'id': 'a', 'lat': 1.0, 'lng': 2.0},
          {'id': 'b', 'lat': null, 'lng': null},
        ],
      }),
    );
    expect(geo.locations.keys, ['a']);
    expect(geo.shape, isEmpty);
  });

  test('rejects a trip with the wrong number of times', () {
    final root = jsonDecode(
      readData('tabriz-metro-line1-schedules.json'),
    ) as Map<String, dynamic>;
    final trips =
        ((((root['schedules'] as Map)['weekday'] as Map)['directions']
                    as Map)['eyl-goli-to-noor']
                as Map)['trips']
            as List;
    (trips.first as List).removeLast();
    expect(
      () => parseTimetable(jsonEncode(root)),
      throwsA(isA<TimetableFormatException>()),
    );
  });

  test('rejects non-monotonic times', () {
    final root = jsonDecode(
      readData('tabriz-metro-line1-schedules.json'),
    ) as Map<String, dynamic>;
    final trip =
        (((((root['schedules'] as Map)['holiday'] as Map)['directions']
                            as Map)['noor-to-eyl-goli']
                        as Map)['trips']
                    as List)
                .first
            as List;
    trip[3] = trip[2];
    expect(
      () => parseTimetable(jsonEncode(root)),
      throwsA(isA<TimetableFormatException>()),
    );
  });

  test('station helpers', () {
    expect(tt.isEndOfLine(17, Direction.towardNoor), isTrue);
    expect(tt.isEndOfLine(0, Direction.towardEylGoli), isTrue);
    expect(tt.isEndOfLine(5, Direction.towardNoor), isFalse);
    expect(tt.directionBetween(2, 9), Direction.towardNoor);
    expect(tt.directionBetween(9, 2), Direction.towardEylGoli);
    expect(tt.directionBetween(4, 4), isNull);
    expect(tt.terminalOf(Direction.towardNoor).id, 'noor');
    expect(Direction.towardNoor.opposite, Direction.towardEylGoli);
    expect(tt.dataVersion, contains('1404/06/31'));
    expect(tt.stationById('nope'), isNull);
  });
}
