import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/models.dart';

enum LocationStatus {
  unknown,
  serviceDisabled,
  denied,
  deniedForever,
  granted,
  unsupported,
}

@immutable
class LocationState {
  const LocationState({
    this.status = LocationStatus.unknown,
    this.position,
    this.accuracy,
    this.loading = false,
  });

  final LocationStatus status;
  final GeoPoint? position;

  /// Horizontal accuracy of [position] in meters, when known.
  final double? accuracy;
  final bool loading;

  bool get granted => status == LocationStatus.granted;

  LocationState copyWith({
    LocationStatus? status,
    GeoPoint? position,
    double? accuracy,
    bool? loading,
  }) => LocationState(
    status: status ?? this.status,
    position: position ?? this.position,
    accuracy: accuracy ?? this.accuracy,
    loading: loading ?? this.loading,
  );
}

/// Device location, processed on-device only. Never requests permission on
/// its own: [request] is called from the explainer screen.
class LocationController extends Notifier<LocationState> {
  StreamSubscription<Position>? _sub;

  @override
  LocationState build() {
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(refreshStatus);
    return const LocationState();
  }

  Future<LocationStatus> _status() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationStatus.serviceDisabled;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationStatus.granted,
        LocationPermission.deniedForever => LocationStatus.deniedForever,
        LocationPermission.denied => LocationStatus.denied,
        LocationPermission.unableToDetermine => LocationStatus.unknown,
      };
    } on Object {
      return LocationStatus.unsupported;
    }
  }

  /// Re-reads permission and, when granted, fetches a fresh position.
  Future<void> refreshStatus() async {
    final status = await _status();
    state = state.copyWith(status: status);
    if (status == LocationStatus.granted && state.position == null) {
      await locate();
    }
  }

  /// Asks for permission (only after the explainer), then locates.
  Future<LocationStatus> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = state.copyWith(status: LocationStatus.serviceDisabled);
        return state.status;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      state = state.copyWith(status: await _status());
      if (state.granted) await locate();
    } on Object {
      state = state.copyWith(status: LocationStatus.unsupported);
    }
    return state.status;
  }

  Future<GeoPoint?> locate() async {
    if (!state.granted) return state.position;
    state = state.copyWith(loading: true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      state = LocationState(
        status: LocationStatus.granted,
        position: GeoPoint(pos.latitude, pos.longitude),
        accuracy: pos.accuracy,
      );
    } on Object {
      state = state.copyWith(loading: false);
    }
    return state.position;
  }

  /// Follows the position while something (map, active trip) listens.
  void startTracking() {
    if (!state.granted || _sub != null) return;
    try {
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            ),
          ).listen(
            (pos) => state = state.copyWith(
              position: GeoPoint(pos.latitude, pos.longitude),
              accuracy: pos.accuracy,
            ),
            onError: (Object _) {},
          );
    } on Object {
      _sub = null;
    }
  }

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> openSettings() async {
    try {
      if (state.status == LocationStatus.serviceDisabled) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } on Object {
      // Not available on this platform.
    }
  }
}

final locationProvider = NotifierProvider<LocationController, LocationState>(
  LocationController.new,
);
