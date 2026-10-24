import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../domain/automation/reminders.dart';
import '../../domain/geo/geo.dart';
import '../../domain/trip/trip_planner.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';
import 'notification_service.dart';

class L10nReminderTexts implements ReminderTexts {
  L10nReminderTexts(this.l, this.fmt, {required this.persian});

  final AppLocalizations l;
  final Fmt fmt;
  final bool persian;

  @override
  String clock(DateTime t) => fmt.clock(t);
  @override
  String commuteBody(String time, String arrival) =>
      l.notifCommuteBody(time, arrival);
  @override
  String commuteTitle(String from, String to) => l.notifCommuteTitle(from, to);
  @override
  String destinationBody(String time) => l.notifDestBody(time);
  @override
  String destinationTitle(String station) => l.notifDestTitle(station);
  @override
  String lastTrainBody(String station, String times) =>
      l.notifLastTrainBody(station, times);
  @override
  String lastTrainTitle() => l.notifLastTrainTitle;
  @override
  String leaveNowBody(String station, String time) =>
      l.notifLeaveNowBody(time, station);
  @override
  String leaveNowTitle() => l.notifLeaveNowTitle;
  @override
  String stationName(Station s) => s.name(persian: persian);
}

/// Keeps scheduled local notifications in sync with the automation
/// settings. Reminders are planned a week ahead and re-planned on every
/// launch and settings change.
class AutomationController {
  AutomationController(this.ref);

  final Ref ref;
  Timer? _debounce;

  ReminderTexts _texts() {
    final s = ref.read(settingsProvider);
    final l = lookupAppLocalizations(Locale(s.languageCode));
    return L10nReminderTexts(
      l,
      ref.read(formatProvider),
      persian: s.languageCode == 'fa',
    );
  }

  void scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), rescheduleAll);
  }

  Future<void> rescheduleAll() async {
    final svc = ref.read(notificationServiceProvider);
    if (!svc.supported) return;
    final s = ref.read(settingsProvider);
    final engine = ref.read(engineProvider);
    final tt = engine.timetable;
    final texts = _texts();
    final now = DateTime.now();

    await svc.cancelBlock(ReminderIds.leaveNow);
    final ln = s.leaveNow;
    final lnStation = tt.stationById(ln.stationId ?? '');
    if (ln.enabled && lnStation != null) {
      for (final r in planLeaveNow(
        engine: engine,
        texts: texts,
        now: now,
        station: lnStation,
        direction: ln.direction,
        time: ln.time,
        walkMinutes: ln.walkMinutes,
      )) {
        await svc.schedule(r);
      }
    }

    await svc.cancelBlock(ReminderIds.lastTrain);
    if (s.lastTrainReminder) {
      final station = ref.read(selectedStationProvider);
      for (final r in planLastTrain(
        engine: engine,
        texts: texts,
        now: now,
        station: tt.stationById(s.defaultStationId ?? '') ?? station,
      )) {
        await svc.schedule(r);
      }
    }

    await svc.cancelBlock(ReminderIds.commute);
    final c = s.commute;
    final home = tt.stationById(c.homeStationId ?? '');
    final work = tt.stationById(c.workStationId ?? '');
    if (c.enabled && home != null && work != null) {
      for (final r in planCommute(
        engine: engine,
        texts: texts,
        now: now,
        home: home,
        work: work,
        time: c.time,
      )) {
        await svc.schedule(r);
      }
    }
  }

  /// Schedules the destination alert for [plan] (from "Start trip").
  Future<bool> startTrip(TripPlan plan) async {
    final svc = ref.read(notificationServiceProvider);
    ref.read(activeTripProvider.notifier).start(plan);
    if (!ref.read(settingsProvider).destinationAlert) return true;
    final granted = await svc.requestPermission();
    await svc.cancelBlock(ReminderIds.destination);
    final r = planDestinationAlert(
      plan: plan,
      texts: _texts(),
      now: DateTime.now(),
    );
    if (r != null) await svc.schedule(r);
    return granted || !svc.supported;
  }

  /// Foreground geofence: when the rider is within [radius] of the stop
  /// before the destination, notify immediately (and only once).
  void onPosition(GeoPoint? pos, {double radius = 250}) {
    final trip = ref.read(activeTripProvider);
    if (trip == null || pos == null || trip.geofenceFired) return;
    if (!ref.read(settingsProvider).destinationGeofence) return;
    final target = trip.plan.penultimateStop.station.location;
    if (target == null || haversineMeters(pos, target) > radius) return;
    ref.read(activeTripProvider.notifier).markGeofenceFired();
    final r = planDestinationAlert(
      plan: trip.plan,
      texts: _texts(),
      now: trip.plan.startAt,
    );
    if (r != null) {
      ref.read(notificationServiceProvider).show(r).ignore();
    }
  }
}

class ActiveTrip {
  const ActiveTrip(this.plan, {this.geofenceFired = false});

  final TripPlan plan;
  final bool geofenceFired;
}

class ActiveTripNotifier extends Notifier<ActiveTrip?> {
  @override
  ActiveTrip? build() => null;

  void start(TripPlan plan) => state = ActiveTrip(plan);

  void markGeofenceFired() {
    if (state != null) state = ActiveTrip(state!.plan, geofenceFired: true);
  }

  void clear() => state = null;
}

final activeTripProvider = NotifierProvider<ActiveTripNotifier, ActiveTrip?>(
  ActiveTripNotifier.new,
);

final automationControllerProvider = Provider<AutomationController>((ref) {
  final c = AutomationController(ref);
  ref.listen<AppSettings>(settingsProvider, (prev, next) {
    if (prev == null ||
        prev.leaveNow != next.leaveNow ||
        prev.commute != next.commute ||
        prev.lastTrainReminder != next.lastTrainReminder ||
        prev.defaultStationId != next.defaultStationId ||
        prev.scheduleMode != next.scheduleMode ||
        prev.languageCode != next.languageCode ||
        prev.persianDigits != next.persianDigits) {
      c.scheduleSoon();
    }
  });
  ref.listen<LocationState>(
    locationProvider,
    (_, next) => c.onPosition(next.position),
  );
  ref.onDispose(() => c._debounce?.cancel());
  return c;
});
