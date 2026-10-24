import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';
import '../domain/geo/geo.dart';
import '../domain/update/releases.dart';

enum ScheduleMode { auto, weekday, holiday }

/// "Leave now" reminder for one station and direction.
@immutable
class LeaveNowConfig {
  const LeaveNowConfig({
    this.enabled = false,
    this.stationId,
    this.direction = Direction.towardNoor,
    this.time = '07:30',
    this.walkMinutes = 10,
  });

  factory LeaveNowConfig.fromJson(Map<String, dynamic> j) => LeaveNowConfig(
    enabled: j['enabled'] as bool? ?? false,
    stationId: j['stationId'] as String?,
    direction: Direction.values.firstWhere(
      (d) => d.id == j['direction'],
      orElse: () => Direction.towardNoor,
    ),
    time: j['time'] as String? ?? '07:30',
    walkMinutes: j['walkMinutes'] as int? ?? 10,
  );

  final bool enabled;
  final String? stationId;
  final Direction direction;

  /// "HH:MM" — the earliest time the rider wants to be on a train.
  final String time;
  final int walkMinutes;

  LeaveNowConfig copyWith({
    bool? enabled,
    String? stationId,
    Direction? direction,
    String? time,
    int? walkMinutes,
  }) => LeaveNowConfig(
    enabled: enabled ?? this.enabled,
    stationId: stationId ?? this.stationId,
    direction: direction ?? this.direction,
    time: time ?? this.time,
    walkMinutes: walkMinutes ?? this.walkMinutes,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'stationId': stationId,
    'direction': direction.id,
    'time': time,
    'walkMinutes': walkMinutes,
  };
}

/// Home → work notification on workdays.
@immutable
class CommuteConfig {
  const CommuteConfig({
    this.enabled = false,
    this.homeStationId,
    this.workStationId,
    this.time = '07:15',
  });

  factory CommuteConfig.fromJson(Map<String, dynamic> j) => CommuteConfig(
    enabled: j['enabled'] as bool? ?? false,
    homeStationId: j['homeStationId'] as String?,
    workStationId: j['workStationId'] as String?,
    time: j['time'] as String? ?? '07:15',
  );

  final bool enabled;
  final String? homeStationId;
  final String? workStationId;
  final String time;

  CommuteConfig copyWith({
    bool? enabled,
    String? homeStationId,
    String? workStationId,
    String? time,
  }) => CommuteConfig(
    enabled: enabled ?? this.enabled,
    homeStationId: homeStationId ?? this.homeStationId,
    workStationId: workStationId ?? this.workStationId,
    time: time ?? this.time,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'homeStationId': homeStationId,
    'workStationId': workStationId,
    'time': time,
  };
}

/// All persisted user preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.persianDigits = true,
    this.languageCode = 'fa',
    this.defaultStationId,
    this.selectedStationId,
    this.walkingSpeed = WalkingSpeed.normal,
    this.scheduleMode = ScheduleMode.auto,
    this.autoCheckUpdates = true,
    this.updateChannel = UpdateChannel.stable,
    this.wifiOnly = false,
    this.skippedVersion,
    this.lastUpdateCheck,
    this.favorites = const [],
    this.leaveNow = const LeaveNowConfig(),
    this.destinationAlert = true,
    this.destinationGeofence = false,
    this.autoNearest = false,
    this.lastTrainReminder = false,
    this.commute = const CommuteConfig(),
    this.locationExplained = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return AppSettings(
      themeMode: pick(ThemeMode.values, j['themeMode'], ThemeMode.system),
      textScale: (j['textScale'] as num?)?.toDouble() ?? 1.0,
      persianDigits: j['persianDigits'] as bool? ?? true,
      languageCode: j['languageCode'] as String? ?? 'fa',
      defaultStationId: j['defaultStationId'] as String?,
      selectedStationId: j['selectedStationId'] as String?,
      walkingSpeed: WalkingSpeed.fromName(j['walkingSpeed'] as String?),
      scheduleMode: pick(
        ScheduleMode.values,
        j['scheduleMode'],
        ScheduleMode.auto,
      ),
      autoCheckUpdates: j['autoCheckUpdates'] as bool? ?? true,
      updateChannel: UpdateChannel.fromName(j['updateChannel'] as String?),
      wifiOnly: j['wifiOnly'] as bool? ?? false,
      skippedVersion: j['skippedVersion'] as String?,
      lastUpdateCheck: DateTime.tryParse(j['lastUpdateCheck'] as String? ?? ''),
      favorites: [
        for (final f in (j['favorites'] as List<dynamic>? ?? const []))
          f as String,
      ],
      leaveNow: LeaveNowConfig.fromJson(
        j['leaveNow'] as Map<String, dynamic>? ?? const {},
      ),
      destinationAlert: j['destinationAlert'] as bool? ?? true,
      destinationGeofence: j['destinationGeofence'] as bool? ?? false,
      autoNearest: j['autoNearest'] as bool? ?? false,
      lastTrainReminder: j['lastTrainReminder'] as bool? ?? false,
      commute: CommuteConfig.fromJson(
        j['commute'] as Map<String, dynamic>? ?? const {},
      ),
      locationExplained: j['locationExplained'] as bool? ?? false,
    );
  }

  final ThemeMode themeMode;
  final double textScale;
  final bool persianDigits;
  final String languageCode;
  final String? defaultStationId;

  /// Station currently shown on Home/Timetable.
  final String? selectedStationId;
  final WalkingSpeed walkingSpeed;
  final ScheduleMode scheduleMode;
  final bool autoCheckUpdates;
  final UpdateChannel updateChannel;
  final bool wifiOnly;
  final String? skippedVersion;
  final DateTime? lastUpdateCheck;
  final List<String> favorites;
  final LeaveNowConfig leaveNow;
  final bool destinationAlert;
  final bool destinationGeofence;
  final bool autoNearest;
  final bool lastTrainReminder;
  final CommuteConfig commute;
  final bool locationExplained;

  ScheduleType? get scheduleOverride => switch (scheduleMode) {
    ScheduleMode.auto => null,
    ScheduleMode.weekday => ScheduleType.weekday,
    ScheduleMode.holiday => ScheduleType.holiday,
  };

  bool isFavorite(String stationId) => favorites.contains(stationId);

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? persianDigits,
    String? languageCode,
    String? Function()? defaultStationId,
    String? selectedStationId,
    WalkingSpeed? walkingSpeed,
    ScheduleMode? scheduleMode,
    bool? autoCheckUpdates,
    UpdateChannel? updateChannel,
    bool? wifiOnly,
    String? Function()? skippedVersion,
    DateTime? lastUpdateCheck,
    List<String>? favorites,
    LeaveNowConfig? leaveNow,
    bool? destinationAlert,
    bool? destinationGeofence,
    bool? autoNearest,
    bool? lastTrainReminder,
    CommuteConfig? commute,
    bool? locationExplained,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    textScale: textScale ?? this.textScale,
    persianDigits: persianDigits ?? this.persianDigits,
    languageCode: languageCode ?? this.languageCode,
    defaultStationId: defaultStationId != null
        ? defaultStationId()
        : this.defaultStationId,
    selectedStationId: selectedStationId ?? this.selectedStationId,
    walkingSpeed: walkingSpeed ?? this.walkingSpeed,
    scheduleMode: scheduleMode ?? this.scheduleMode,
    autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
    updateChannel: updateChannel ?? this.updateChannel,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    skippedVersion: skippedVersion != null
        ? skippedVersion()
        : this.skippedVersion,
    lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
    favorites: favorites ?? this.favorites,
    leaveNow: leaveNow ?? this.leaveNow,
    destinationAlert: destinationAlert ?? this.destinationAlert,
    destinationGeofence: destinationGeofence ?? this.destinationGeofence,
    autoNearest: autoNearest ?? this.autoNearest,
    lastTrainReminder: lastTrainReminder ?? this.lastTrainReminder,
    commute: commute ?? this.commute,
    locationExplained: locationExplained ?? this.locationExplained,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'textScale': textScale,
    'persianDigits': persianDigits,
    'languageCode': languageCode,
    'defaultStationId': defaultStationId,
    'selectedStationId': selectedStationId,
    'walkingSpeed': walkingSpeed.name,
    'scheduleMode': scheduleMode.name,
    'autoCheckUpdates': autoCheckUpdates,
    'updateChannel': updateChannel.name,
    'wifiOnly': wifiOnly,
    'skippedVersion': skippedVersion,
    'lastUpdateCheck': lastUpdateCheck?.toIso8601String(),
    'favorites': favorites,
    'leaveNow': leaveNow.toJson(),
    'destinationAlert': destinationAlert,
    'destinationGeofence': destinationGeofence,
    'autoNearest': autoNearest,
    'lastTrainReminder': lastTrainReminder,
    'commute': commute.toJson(),
    'locationExplained': locationExplained,
  };
}

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

const _settingsKey = 'settings.v1';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const AppSettings();
    }
  }

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    ref
        .read(sharedPreferencesProvider)
        .setString(_settingsKey, jsonEncode(state.toJson()))
        .ignore();
  }

  void toggleFavorite(String stationId) => update((s) {
    final favs = [...s.favorites];
    favs.contains(stationId) ? favs.remove(stationId) : favs.add(stationId);
    return s.copyWith(favorites: favs);
  });

  void selectStation(String stationId) =>
      update((s) => s.copyWith(selectedStationId: stationId));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
