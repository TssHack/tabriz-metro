import 'dart:async';

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

/// Vertical schematic of Line 1 with timetable-derived train positions that
/// glide along the rail.
class SchematicView extends ConsumerStatefulWidget {
  const SchematicView({super.key});

  static const rowHeight = 68.0;
  static const railX = 34.0;
  static const railWidth = 8.0;

  @override
  ConsumerState<SchematicView> createState() => _SchematicViewState();
}

class _SchematicViewState extends ConsumerState<SchematicView> {
  Direction _direction = Direction.towardNoor;
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  Timer? _ticker;
  DateTime? _base;
  final _sinceBase = Stopwatch();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    // Smooth train motion: advance the clock locally every second between
    // the app-wide clock ticks.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  DateTime _now(DateTime appNow) {
    if (_base != appNow) {
      _base = appNow;
      _sinceBase
        ..reset()
        ..start();
    }
    return appNow.add(_sinceBase.elapsed);
  }

  void _scrollToRow(int row) {
    final header = _headerKey.currentContext?.size?.height ?? 160;
    final target = header + row * SchematicView.rowHeight - 120;
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final engine = ref.watch(engineProvider);
    final now = _now(ref.watch(nowProvider));
    final fmt = ref.watch(formatProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final selected = ref.watch(selectedStationProvider);
    final n = tt.stationCount;
    final order = _direction == Direction.towardNoor
        ? List<int>.generate(n, (i) => i)
        : List<int>.generate(n, (i) => n - 1 - i);
    final rowOf = {for (final (row, idx) in order.indexed) idx: row};
    final positions = engine.trainPositions(_direction, now);
    final arriving = {
      for (final p in positions)
        if (p.progress >= 0.5) p.toIndex,
    };
    final schedule = engine.scheduleFor(now);
    final selectedRow = rowOf[selected.index]!;

    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToRow(selectedRow),
      );
    }

    const h = SchematicView.rowHeight;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        4,
        AppSizes.gutter,
        24,
      ),
      children: [
        _DirectionHeader(
          key: _headerKey,
          from: tt.stations[order.first].name(persian: fa),
          to: tt.stations[order.last].name(persian: fa),
          headway: l.headwayEvery(fmt.digits(schedule.headwayMinutes)),
          running: l.trainsRunning(fmt.digits(positions.length)),
          onSwap: () => setState(() {
            _direction = _direction.opposite;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToRow(n - 1 - selectedRow),
            );
          }),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: t.border),
            boxShadow: softShadow(context),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            height: h * n,
            child: Stack(
              children: [
                // Rail: travelled (before your station) is soft, upcoming
                // (from your station onward) is solid.
                _Rail(
                  top: h / 2,
                  height: h * selectedRow,
                  color: t.line1.withValues(alpha: 0.35),
                ),
                _Rail(
                  top: h / 2 + h * selectedRow,
                  height: h * (n - 1 - selectedRow),
                  color: t.line1,
                ),
                for (final (row, idx) in order.indexed)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: row * h,
                    height: h,
                    child: _StationRow(
                      station: tt.stations[idx],
                      timetable: tt,
                      isSelected: idx == selected.index,
                      isArriving: arriving.contains(idx),
                      next: tt.isEndOfLine(idx, _direction)
                          ? null
                          : engine.nextDeparture(idx, _direction, now),
                      now: now,
                      fmt: fmt,
                      persian: fa,
                      onTap: () => context.push(
                        Routes.stationTimetable(tt.stations[idx].id),
                      ),
                    ),
                  ),
                for (final p in positions)
                  AnimatedPositionedDirectional(
                    key: ValueKey('train-${p.tripIndex}'),
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                    start: SchematicView.railX - 15,
                    top: (rowOf[p.fromIndex]! + p.progress) * h + h / 2 - 15,
                    child: _TrainChip(label: l.arriving),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(l.estimatedNote, style: TextStyle(color: t.fgMuted, fontSize: 12)),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.top, required this.height, required this.color});

  final double top;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    start: SchematicView.railX - SchematicView.railWidth / 2,
    top: top,
    height: height,
    child: Container(
      width: SchematicView.railWidth,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SchematicView.railWidth),
      ),
    ),
  );
}

class _DirectionHeader extends StatelessWidget {
  const _DirectionHeader({
    super.key,
    required this.from,
    required this.to,
    required this.headway,
    required this.running,
    required this.onSwap,
  });

  final String from;
  final String to;
  final String headway;
  final String running;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final onHero = t.onHero;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [t.hero, t.heroB],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: softShadow(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        from,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onHero,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        LucideIcons.arrowRightDir,
                        size: 18,
                        color: onHero.withValues(alpha: 0.8),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        to,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onHero,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pill(
                      icon: LucideIcons.timer,
                      label: headway,
                      background: onHero.withValues(alpha: 0.14),
                      foreground: onHero,
                    ),
                    Pill(
                      icon: LucideIcons.trainFront,
                      label: running,
                      background: onHero.withValues(alpha: 0.14),
                      foreground: onHero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.swapDirection,
            onPressed: onSwap,
            style: IconButton.styleFrom(
              backgroundColor: onHero.withValues(alpha: 0.14),
            ),
            icon: Icon(LucideIcons.arrowDownUp, color: onHero),
          ),
        ],
      ),
    );
  }
}

class _TrainChip extends StatelessWidget {
  const _TrainChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: label,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: t.primary,
          shape: BoxShape.circle,
          border: Border.all(color: t.surface, width: 3),
          boxShadow: [
            BoxShadow(color: t.primary.withValues(alpha: 0.45), blurRadius: 10),
          ],
        ),
        child: Icon(LucideIcons.trainFront, size: 14, color: t.onPrimary),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.timetable,
    required this.isSelected,
    required this.isArriving,
    required this.next,
    required this.now,
    required this.fmt,
    required this.persian,
    required this.onTap,
  });

  final Station station;
  final Timetable timetable;
  final bool isSelected;
  final bool isArriving;
  final Departure? next;
  final DateTime now;
  final Fmt fmt;
  final bool persian;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final terminal =
        station.index == 0 || station.index == timetable.stationCount - 1;
    final mins = next?.minutesFrom(now);
    final today = next != null && next!.serviceDay.day == now.day;

    Widget node;
    if (terminal) {
      node = Container(
        width: 30,
        height: 18,
        decoration: BoxDecoration(
          color: t.line1,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: t.surface, width: 3),
        ),
      );
    } else if (station.isHub) {
      node = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: t.surface,
          shape: BoxShape.circle,
          border: Border.all(color: t.line1, width: 5),
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: t.line1, shape: BoxShape.circle),
          ),
        ),
      );
    } else {
      node = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: t.surface,
          shape: BoxShape.circle,
          border: Border.all(color: t.line1, width: 4),
        ),
      );
    }
    if (isSelected) {
      node = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: terminal ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: terminal ? BorderRadius.circular(AppRadii.chip) : null,
          border: Border.all(color: t.primary, width: 2.5),
        ),
        child: node,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: SchematicView.railX * 2,
            child: Center(child: node),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name(persian: persian),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: station.isHub || isSelected || terminal
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 15,
                    color: isSelected ? t.primary : t.fg,
                  ),
                ),
                // One tag at a time keeps rows a fixed height.
                if (isSelected)
                  _Tag(l.youAreHere, t.primarySoft, t.primary)
                else if (isArriving)
                  _Tag(l.arriving, t.successSoft, t.success)
                else if (station.isHub)
                  _Tag(l.hub, t.line1Soft, t.line1),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 104),
            padding: const EdgeInsetsDirectional.only(end: 14, start: 6),
            child: next == null
                ? Text('—', style: TextStyle(color: t.fgMuted))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.clock(next!.time),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: today ? t.fg : t.fgMuted,
                        ),
                      ),
                      if (today && mins != null)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: mins <= 2 ? t.line1Soft : t.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                          ),
                          child: Text(
                            mins == 0 ? l.now : l.inMinutes(fmt.digits(mins)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mins <= 2 ? t.line1 : t.fgMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.bg, this.fg);

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 3),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
