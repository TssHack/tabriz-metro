import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/automation/reminders.dart';

/// Thin wrapper around flutter_local_notifications. All notifications are
/// local; nothing is sent to a server.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _channelName = 'Trip reminders';
  String _channelDesc = '';

  /// Called with the payload when the user taps a notification.
  void Function(String? payload)? onTap;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> init({String? channelName, String? channelDesc}) async {
    if (channelName != null) _channelName = channelName;
    if (channelDesc != null) _channelDesc = channelDesc;
    if (_ready || !supported) return;
    try {
      tzdata.initializeTimeZones();
      String zone;
      try {
        zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      } on Object {
        zone = 'Asia/Tehran';
      }
      try {
        tz.setLocalLocation(tz.getLocation(zone));
      } on Object {
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      }
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      );
      _ready = true;
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      return (d?.didNotificationLaunchApp ?? false)
          ? d?.notificationResponse?.payload
          : null;
    } on Object {
      return null;
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      'trip_reminders',
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );

  Future<void> schedule(PlannedReminder r) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: _details,
        // Inexact alarms need no special permission; a minute of drift is
        // acceptable for these reminders.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.payload,
      );
    } on Object catch (e) {
      debugPrint('Failed to schedule ${r.id}: $e');
    }
  }

  Future<void> show(PlannedReminder r) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        notificationDetails: _details,
        payload: r.payload,
      );
    } on Object {
      // ignore
    }
  }

  /// Cancels every id in the block starting at [base].
  Future<void> cancelBlock(int base) async {
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= base && p.id < base + ReminderIds.blockSize) {
          await _plugin.cancel(id: p.id);
        }
      }
    } on Object {
      // ignore
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
