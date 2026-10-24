import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/settings.dart';
import '../../data/repositories/update_repository.dart';
import '../../domain/update/releases.dart';
import '../../domain/update/semver.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  readyToInstall,
  error,
}

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.currentVersion,
    this.release,
    this.apk,
    this.progress = 0,
    this.error,
    this.errorMessage = '',
  });

  final UpdatePhase phase;
  final String? currentVersion;
  final Release? release;
  final ReleaseAsset? apk;
  final double progress;
  final UpdateErrorKind? error;
  final String errorMessage;

  /// Release to advertise (e.g. on Home), when one is newer.
  Release? get available => switch (phase) {
    UpdatePhase.available ||
    UpdatePhase.downloading ||
    UpdatePhase.verifying ||
    UpdatePhase.readyToInstall => release,
    _ => null,
  };

  UpdateState copyWith({
    UpdatePhase? phase,
    String? currentVersion,
    Release? release,
    ReleaseAsset? apk,
    double? progress,
    UpdateErrorKind? error,
    String? errorMessage,
  }) => UpdateState(
    phase: phase ?? this.phase,
    currentVersion: currentVersion ?? this.currentVersion,
    release: release ?? this.release,
    apk: apk ?? this.apk,
    progress: progress ?? this.progress,
    error: error,
    errorMessage: errorMessage ?? '',
  );
}

/// Installed app version (from the platform package info).
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return '0.0.0';
  }
});

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => UpdateRepository(),
);

/// Whether this build can download and install APKs itself.
bool get canSelfInstall => !kIsWeb && Platform.isAndroid;

class UpdateController extends Notifier<UpdateState> {
  String? _apkPath;

  @override
  UpdateState build() => const UpdateState();

  Future<String> _currentVersion() async {
    return state.currentVersion ?? await ref.read(appVersionProvider.future);
  }

  Future<List<String>> _abis() async {
    if (!canSelfInstall) return const [];
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.supportedAbis;
    } on Object {
      return const ['arm64-v8a', 'armeabi-v7a'];
    }
  }

  /// Daily background check from app start.
  Future<void> autoCheck() async {
    final s = ref.read(settingsProvider);
    if (!s.autoCheckUpdates) return;
    final last = s.lastUpdateCheck;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 24)) {
      return;
    }
    await check(silent: true);
  }

  Future<void> check({bool silent = false}) async {
    if (state.phase == UpdatePhase.checking ||
        state.phase == UpdatePhase.downloading) {
      return;
    }
    final current = await _currentVersion();
    state = state.copyWith(
      phase: UpdatePhase.checking,
      currentVersion: current,
    );
    try {
      final releases = await ref.read(updateRepositoryProvider).fetchReleases();
      final s = ref.read(settingsProvider);
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(lastUpdateCheck: DateTime.now()));
      final r = selectUpdate(
        releases,
        current: SemVer.tryParse(current) ?? const SemVer(0, 0, 0),
        channel: s.updateChannel,
        skippedVersion: silent ? s.skippedVersion : null,
      );
      if (r == null) {
        state = UpdateState(
          phase: UpdatePhase.upToDate,
          currentVersion: current,
        );
        return;
      }
      final apk = canSelfInstall ? pickApkAsset(r, abis: await _abis()) : null;
      state = UpdateState(
        phase: UpdatePhase.available,
        currentVersion: current,
        release: r,
        apk: apk,
      );
    } on UpdateException catch (e) {
      state = silent
          ? UpdateState(currentVersion: current)
          : state.copyWith(
              phase: UpdatePhase.error,
              error: e.kind,
              errorMessage: e.message,
            );
    } on Object catch (e) {
      state = silent
          ? UpdateState(currentVersion: current)
          : state.copyWith(
              phase: UpdatePhase.error,
              error: UpdateErrorKind.other,
              errorMessage: '$e',
            );
    }
  }

  /// Returns false (and leaves state unchanged) when Wi-Fi is required but
  /// the device is not on Wi-Fi/Ethernet.
  Future<bool> _networkAllowed() async {
    if (!ref.read(settingsProvider).wifiOnly) return true;
    try {
      final c = await Connectivity().checkConnectivity();
      return c.contains(ConnectivityResult.wifi) ||
          c.contains(ConnectivityResult.ethernet);
    } on Object {
      return false;
    }
  }

  /// Downloads the APK, verifies SHA-256 and opens the system installer.
  /// Returns false when blocked by the Wi-Fi-only setting.
  Future<bool> downloadAndInstall() async {
    final r = state.release;
    final apk = state.apk;
    if (r == null) return true;
    if (apk == null) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        error: UpdateErrorKind.noApk,
      );
      return true;
    }
    if (!await _networkAllowed()) return false;
    final repo = ref.read(updateRepositoryProvider);
    try {
      state = state.copyWith(phase: UpdatePhase.downloading, progress: 0);
      final expected = await repo.expectedChecksum(r, apk);
      final file = await repo.downloadVerified(
        apk,
        expected,
        onProgress: (p) =>
            state = state.copyWith(phase: UpdatePhase.downloading, progress: p),
        onVerifying: () =>
            state = state.copyWith(phase: UpdatePhase.verifying, progress: 1),
      );
      _apkPath = file.path;
      state = state.copyWith(phase: UpdatePhase.readyToInstall, progress: 1);
      await install();
    } on UpdateException catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        error: e.kind,
        errorMessage: e.message,
      );
    } on Object catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        error: UpdateErrorKind.other,
        errorMessage: '$e',
      );
    }
    return true;
  }

  Future<void> install() async {
    final path = _apkPath;
    if (path == null) return;
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void skipCurrent() {
    final v = state.release?.version?.toString();
    if (v == null) return;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(skippedVersion: () => v));
    state = UpdateState(
      phase: UpdatePhase.upToDate,
      currentVersion: state.currentVersion,
    );
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
