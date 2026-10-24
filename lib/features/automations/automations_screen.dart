import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';
import '../stations/station_picker.dart';
import 'notification_service.dart';

class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final tt = ref.watch(timetableProvider);
    final fmt = ref.watch(formatProvider);
    final data = ref.watch(appDataProvider);
    final fa = s.languageCode == 'fa';

    String stationName(String? id) =>
        tt.stationById(id ?? '')?.name(persian: fa) ?? l.chooseStation;

    Future<bool> ensureNotifications() async {
      final ok = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
      }
      return true;
    }

    Future<String?> pickTime(String current) async {
      final m = parseHhMm(current);
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      );
      if (picked == null) return null;
      return formatMinutes(picked.hour * 60 + picked.minute);
    }

    Future<String?> pickStation(String? current, String title) async =>
        (await showStationPicker(
          context,
          title: title,
          selectedId: current,
        ))?.id;

    final ln = s.leaveNow;
    final c = s.commute;
    final lastTrainStation =
        tt.stationById(s.defaultStationId ?? '') ??
        ref.watch<Station>(selectedStationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.automations)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.gutter),
        children: [
          InfoBanner(
            icon: LucideIcons.bellRing,
            child: Text(l.automationsIntro),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 8),
            InfoBanner(
              warning: true,
              icon: LucideIcons.triangleAlert,
              child: Text(l.notificationsWebUnsupported),
            ),
          ],
          const SizedBox(height: 12),
          _AutomationCard(
            icon: LucideIcons.alarmClock,
            title: l.autoLeaveNow,
            subtitle: l.autoLeaveNowDesc,
            value: ln.enabled,
            onChanged: (v) async {
              if (v) await ensureNotifications();
              n.update(
                (x) => x.copyWith(
                  leaveNow: x.leaveNow.copyWith(
                    enabled: v,
                    stationId:
                        x.leaveNow.stationId ??
                        (x.favorites.isNotEmpty
                            ? x.favorites.first
                            : ref.read(selectedStationProvider).id),
                  ),
                ),
              );
            },
            children: [
              _ConfigRow(
                label: l.station,
                value: stationName(ln.stationId),
                onTap: () async {
                  final id = await pickStation(ln.stationId, l.station);
                  if (id != null) {
                    n.update(
                      (x) => x.copyWith(
                        leaveNow: x.leaveNow.copyWith(stationId: id),
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SegmentedButton<Direction>(
                  segments: [
                    for (final d in Direction.values)
                      ButtonSegment(
                        value: d,
                        label: Text(
                          l.towardStation(tt.terminalOf(d).name(persian: fa)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  selected: {ln.direction},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => n.update(
                    (x) => x.copyWith(
                      leaveNow: x.leaveNow.copyWith(direction: v.first),
                    ),
                  ),
                ),
              ),
              _ConfigRow(
                label: l.reminderTime,
                value: fmt.digits(ln.time),
                onTap: () async {
                  final v = await pickTime(ln.time);
                  if (v != null) {
                    n.update(
                      (x) => x.copyWith(leaveNow: x.leaveNow.copyWith(time: v)),
                    );
                  }
                },
              ),
              Row(
                children: [
                  Expanded(child: Text(l.walkToStationMinutes)),
                  IconButton(
                    tooltip: '−',
                    onPressed: ln.walkMinutes <= 0
                        ? null
                        : () => n.update(
                            (x) => x.copyWith(
                              leaveNow: x.leaveNow.copyWith(
                                walkMinutes: x.leaveNow.walkMinutes - 1,
                              ),
                            ),
                          ),
                    icon: const Icon(LucideIcons.minus),
                  ),
                  Text(
                    l.minutesValue(fmt.digits(ln.walkMinutes)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: '+',
                    onPressed: ln.walkMinutes >= 60
                        ? null
                        : () => n.update(
                            (x) => x.copyWith(
                              leaveNow: x.leaveNow.copyWith(
                                walkMinutes: x.leaveNow.walkMinutes + 1,
                              ),
                            ),
                          ),
                    icon: const Icon(LucideIcons.plus),
                  ),
                ],
              ),
            ],
          ),
          _AutomationCard(
            icon: LucideIcons.bellRing,
            title: l.autoDestination,
            subtitle: l.autoDestinationDesc,
            value: s.destinationAlert,
            onChanged: (v) async {
              if (v) await ensureNotifications();
              n.update((x) => x.copyWith(destinationAlert: v));
            },
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.destinationGeofence,
                title: Text(l.geofence),
                onChanged: (v) async {
                  if (v && !ref.read(locationProvider).granted) {
                    await context.push(Routes.location);
                    if (!ref.read(locationProvider).granted) return;
                  }
                  n.update((x) => x.copyWith(destinationGeofence: v));
                },
              ),
            ],
          ),
          _AutomationCard(
            icon: LucideIcons.locateFixed,
            title: l.autoNearest,
            subtitle: l.autoNearestDesc,
            value: s.autoNearest,
            onChanged: (v) async {
              if (v && !ref.read(locationProvider).granted) {
                await context.push(Routes.location);
                if (!ref.read(locationProvider).granted) return;
              }
              n.update((x) => x.copyWith(autoNearest: v));
            },
          ),
          _AutomationCard(
            icon: LucideIcons.calendarDays,
            title: l.autoDayType,
            subtitle: l.autoDayTypeDesc,
            value: s.scheduleMode == ScheduleMode.auto,
            onChanged: (v) => n.update(
              (x) => x.copyWith(
                scheduleMode: v ? ScheduleMode.auto : ScheduleMode.weekday,
              ),
            ),
            children: [
              if (data.holidays.needsReview)
                Text(
                  l.holidaysNeedReview,
                  style: TextStyle(color: t.warning, fontSize: 12.5),
                ),
            ],
          ),
          _AutomationCard(
            icon: LucideIcons.moonStar,
            title: l.autoLastTrain,
            subtitle: l.autoLastTrainDesc,
            value: s.lastTrainReminder,
            onChanged: (v) async {
              if (v) await ensureNotifications();
              n.update((x) => x.copyWith(lastTrainReminder: v));
            },
            children: [
              _ConfigRow(
                label: l.station,
                value: lastTrainStation.name(persian: fa),
                onTap: () async {
                  final id = await pickStation(
                    s.defaultStationId,
                    l.defaultStation,
                  );
                  if (id != null) {
                    n.update((x) => x.copyWith(defaultStationId: () => id));
                  }
                },
              ),
            ],
          ),
          _AutomationCard(
            icon: LucideIcons.briefcase,
            title: l.autoCommute,
            subtitle: l.autoCommuteDesc,
            value: c.enabled,
            onChanged: (v) async {
              if (v) await ensureNotifications();
              n.update(
                (x) => x.copyWith(commute: x.commute.copyWith(enabled: v)),
              );
            },
            children: [
              _ConfigRow(
                label: l.homeStation,
                value: stationName(c.homeStationId),
                onTap: () async {
                  final id = await pickStation(c.homeStationId, l.homeStation);
                  if (id != null) {
                    n.update(
                      (x) => x.copyWith(
                        commute: x.commute.copyWith(homeStationId: id),
                      ),
                    );
                  }
                },
              ),
              _ConfigRow(
                label: l.workStation,
                value: stationName(c.workStationId),
                onTap: () async {
                  final id = await pickStation(c.workStationId, l.workStation);
                  if (id != null) {
                    n.update(
                      (x) => x.copyWith(
                        commute: x.commute.copyWith(workStationId: id),
                      ),
                    );
                  }
                },
              ),
              _ConfigRow(
                label: l.reminderTime,
                value: fmt.digits(c.time),
                onTap: () async {
                  final v = await pickTime(c.time);
                  if (v != null) {
                    n.update(
                      (x) => x.copyWith(commute: x.commute.copyWith(time: v)),
                    );
                  }
                },
              ),
              if (c.homeStationId != null && c.workStationId != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => context.push(
                      Routes.tripFromTo(
                        from: c.homeStationId,
                        to: c.workStationId,
                      ),
                    ),
                    icon: const Icon(LucideIcons.navigation, size: 16),
                    label: Text(l.planTrip),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: value ? t.primarySoft : t.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: value ? t.primary : t.fgMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: t.fgMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (value && children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(color: t.border),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(color: t.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRightDir, size: 16, color: t.fgMuted),
          ],
        ),
      ),
    );
  }
}
