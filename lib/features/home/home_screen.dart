import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/schedule/schedule_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../stations/station_picker.dart';
import '../update/update_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final station = ref.watch(selectedStationProvider);
    final engine = ref.watch(engineProvider);
    final now = ref.watch(nowProvider);
    final fmt = ref.watch(formatProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final favorites = ref.watch(favoriteStationsProvider);
    final update = ref.watch(updateControllerProvider);
    final type = engine.scheduleTypeFor(now);
    final schedule = engine.timetable[type];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            onBell: () => context.push(Routes.automations),
            onSettings: () => context.push(Routes.settings),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StationCard(
                    station: station,
                    persian: fa,
                    dayLabel: type == ScheduleType.weekday
                        ? l.weekday
                        : l.holiday,
                    headwayLabel: l.headwayEvery(
                      fmt.digits(schedule.headwayMinutes),
                    ),
                    onChange: () async {
                      final s = await showStationPicker(
                        context,
                        selectedId: station.id,
                      );
                      if (s != null) {
                        ref.read(settingsProvider.notifier).selectStation(s.id);
                      }
                    },
                  ),
                  if (update.available case final r?) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      icon: LucideIcons.download,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.updateBanner(fmt.digits(r.version.toString())),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push(Routes.update),
                            child: Text(l.view),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SectionTitle(
                    l.nextTrains,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LiveDot(),
                        const SizedBox(width: 6),
                        Text(
                          l.live,
                          style: TextStyle(color: t.fgMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  for (final d in Direction.values) ...[
                    DepartureCard(
                      station: station,
                      direction: d,
                      engine: engine,
                      now: now,
                      fmt: fmt,
                      persian: fa,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    l.estimatedNote,
                    style: TextStyle(color: t.fgMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push(Routes.tripFromTo(from: station.id)),
                    icon: const Icon(LucideIcons.navigation, size: 18),
                    label: Text(l.planTrip),
                  ),
                  SectionTitle(l.favoriteStations),
                  if (favorites.isEmpty)
                    Text(l.noFavorites, style: TextStyle(color: t.fgMuted))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in favorites)
                          ActionChip(
                            avatar: Icon(
                              LucideIcons.star,
                              size: 16,
                              color: t.warning,
                            ),
                            label: Text(f.name(persian: fa)),
                            backgroundColor: f.id == station.id
                                ? t.primarySoft
                                : t.surface,
                            onPressed: () => ref
                                .read(settingsProvider.notifier)
                                .selectStation(f.id),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onBell, required this.onSettings});

  final VoidCallback onBell;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [t.hero, t.heroB],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        12,
        60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.appTitle,
                  style: TextStyle(
                    color: t.onHero,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.line1,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.onHero, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.lineRoute,
                        style: TextStyle(
                          color: t.onHero.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.automations,
            onPressed: onBell,
            icon: Icon(LucideIcons.bell, color: t.onHero),
          ),
          IconButton(
            tooltip: l.settings,
            onPressed: onSettings,
            icon: Icon(LucideIcons.settings, color: t.onHero),
          ),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.persian,
    required this.dayLabel,
    required this.headwayLabel,
    required this.onChange,
  });

  final Station station;
  final bool persian;
  final String dayLabel;
  final String headwayLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return AppCard(
      onTap: onChange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.line1Soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(LucideIcons.mapPin, color: t.line1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.yourStation,
                      style: TextStyle(color: t.fgMuted, fontSize: 12),
                    ),
                    Text(
                      station.name(persian: persian),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onChange,
                icon: const Icon(LucideIcons.chevronDown, size: 18),
                label: Text(l.changeStation),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(
                icon: LucideIcons.calendarDays,
                label: dayLabel,
                background: t.primarySoft,
                foreground: t.primary,
              ),
              Pill(icon: LucideIcons.timer, label: headwayLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// Next trains from one station in one direction, with a big countdown.
class DepartureCard extends StatelessWidget {
  const DepartureCard({
    super.key,
    required this.station,
    required this.direction,
    required this.engine,
    required this.now,
    required this.fmt,
    required this.persian,
  });

  final Station station;
  final Direction direction;
  final ScheduleEngine engine;
  final DateTime now;
  final Fmt fmt;
  final bool persian;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = engine.timetable;
    final terminal = tt.terminalOf(direction).name(persian: persian);
    final header = Row(
      children: [
        Icon(LucideIcons.trainFront, size: 18, color: t.line1),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l.towardStation(terminal),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );

    if (tt.isEndOfLine(station.index, direction)) {
      return AppCard(
        color: t.surface2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            Text(l.endOfLineHere, style: TextStyle(color: t.fgMuted)),
          ],
        ),
      );
    }

    final next = engine.nextDepartures(station.index, direction, now, count: 4);
    if (next.isEmpty) return const SizedBox.shrink();
    final first = next.first;
    final today =
        first.serviceDay.day == now.day && first.serviceDay.month == now.month;
    final mins = first.minutesFrom(now);

    return Semantics(
      container: true,
      label: '${l.towardStation(terminal)}, ${fmt.clock(first.time)}',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!today)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.noMoreTrainsToday,
                          style: TextStyle(
                            color: t.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(l.firstTrainNextDay(fmt.clock(first.time))),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    mins == 0 ? l.now : fmt.digits(mins),
                    style: TextStyle(
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: mins <= 2 ? t.line1 : t.primary,
                    ),
                  ),
                  if (mins > 0) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        l.minutesUnit,
                        style: TextStyle(color: t.fgMuted, fontSize: 14),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l.departsAt(fmt.clock(first.time)),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        l.estimated,
                        style: TextStyle(color: t.fgMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (next.length > 1) ...[
              const SizedBox(height: 12),
              Divider(color: t.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    l.thenAt,
                    style: TextStyle(color: t.fgMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  for (final d in next.skip(1)) ...[
                    Pill(label: fmt.clock(d.time)),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
