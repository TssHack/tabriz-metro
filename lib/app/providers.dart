import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/format.dart';
import '../data/models/models.dart';
import '../domain/schedule/holiday_calendar.dart';
import '../domain/schedule/schedule_engine.dart';
import 'settings.dart';

/// Bundled data loaded once at startup.
class AppData {
  const AppData({required this.timetable, required this.holidays});

  final Timetable timetable;
  final HolidayCalendar holidays;
}

/// Overridden in `main()` (and in tests) with the loaded data.
final appDataProvider = Provider<AppData>(
  (ref) => throw UnimplementedError('appDataProvider not overridden'),
);

final timetableProvider = Provider<Timetable>(
  (ref) => ref.watch(appDataProvider).timetable,
);

final engineProvider = Provider<ScheduleEngine>((ref) {
  final data = ref.watch(appDataProvider);
  final override = ref.watch(
    settingsProvider.select((s) => s.scheduleOverride),
  );
  return ScheduleEngine(data.timetable, data.holidays, override: override);
});

/// Ticks at the start of every minute (and every 15 s for live dots).
final clockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(
    const Duration(seconds: 15),
    (_) => controller.add(DateTime.now()),
  );
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// The current time; override with a fixed value in tests.
final nowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider).value ?? DateTime.now(),
);

final formatProvider = Provider<Fmt>((ref) {
  final persian = ref.watch(settingsProvider.select((s) => s.persianDigits));
  return Fmt(persianDigits: persian);
});

/// The station shown on Home/Timetable: the last selected one, else the
/// default station, else Eyl Goli.
final selectedStationProvider = Provider<Station>((ref) {
  final tt = ref.watch(timetableProvider);
  final s = ref.watch(settingsProvider);
  return tt.stationById(s.selectedStationId ?? '') ??
      tt.stationById(s.defaultStationId ?? '') ??
      tt.stations.first;
});

final favoriteStationsProvider = Provider<List<Station>>((ref) {
  final tt = ref.watch(timetableProvider);
  final favs = ref.watch(settingsProvider.select((s) => s.favorites));
  return [for (final id in favs) ?tt.stationById(id)];
});
