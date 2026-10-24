import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../domain/geo/geo.dart';
import '../features/automations/automation_controller.dart';
import '../features/automations/notification_service.dart';
import '../features/location/location_controller.dart';
import '../features/update/update_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'settings.dart';

class TabrizMetroApp extends ConsumerStatefulWidget {
  const TabrizMetroApp({super.key, this.runStartupTasks = true});

  /// Disabled in widget tests (no platform plugins there).
  final bool runStartupTasks;

  @override
  ConsumerState<TabrizMetroApp> createState() => _TabrizMetroAppState();
}

class _TabrizMetroAppState extends ConsumerState<TabrizMetroApp> {
  @override
  void initState() {
    super.initState();
    if (widget.runStartupTasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
    }
  }

  Future<void> _startup() async {
    final settings = ref.read(settingsProvider);
    final l = lookupAppLocalizations(Locale(settings.languageCode));

    // Local notifications; tapping one deep-links into the app.
    final svc = ref.read(notificationServiceProvider)..onTap = _openPayload;
    await svc.init(
      channelName: l.notifChannelName,
      channelDesc: l.notifChannelDesc,
    );
    ref.read(automationControllerProvider).scheduleSoon();
    _openPayload(await svc.launchPayload());

    // Auto-select the nearest station (only if permission was granted
    // earlier; never prompts on launch).
    if (settings.autoNearest) {
      final loc = ref.read(locationProvider.notifier);
      await loc.refreshStatus();
      final pos = await loc.locate();
      if (pos != null) {
        final n = nearestStation(ref.read(timetableProvider).stations, pos);
        if (n != null) {
          ref.read(settingsProvider.notifier).selectStation(n.station.id);
        }
      }
    }

    await ref.read(updateControllerProvider.notifier).autoCheck();
  }

  /// Payloads: `station:<id>` or `trip:<from>:<to>`.
  void _openPayload(String? payload) {
    if (payload == null) return;
    final parts = payload.split(':');
    final router = ref.read(routerProvider);
    if (parts.first == 'station' && parts.length == 2) {
      ref.read(settingsProvider.notifier).selectStation(parts[1]);
      router.go(Routes.home);
    } else if (parts.first == 'trip' && parts.length == 3) {
      router.push(Routes.tripFromTo(from: parts[1], to: parts[2]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: Locale(settings.languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            // The in-app text size multiplies the system setting.
            textScaler: TextScaler.linear(
              (mq.textScaler.scale(1) * settings.textScale).clamp(0.8, 2.0),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
