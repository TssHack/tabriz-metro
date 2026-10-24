import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';

/// Vertical schematic of Line 1 with timetable-derived train positions.
class SchematicView extends ConsumerStatefulWidget {
  const SchematicView({super.key});

  static const rowHeight = 64.0;
  static const railWidth = 48.0;

  @override
  ConsumerState<SchematicView> createState() => _SchematicViewState();
}

class _SchematicViewState extends ConsumerState<SchematicView> {
  Direction _direction = Direction.towardNoor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final engine = ref.watch(engineProvider);
    final now = ref.watch(nowProvider);
    final fmt = ref.watch(formatProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final selected = ref.watch(selectedStationProvider);
    final n = tt.stationCount;
    // Rows in travel order, top to bottom.
    final order = _direction == Direction.towardNoor
        ? List<int>.generate(n, (i) => i)
        : List<int>.generate(n, (i) => n - 1 - i);
    final rowOf = {for (final (row, idx) in order.indexed) idx: row};
    final positions = engine.trainPositions(_direction, now);
    final arriving = {for (final p in positions) p.toIndex};
    const h = SchematicView.rowHeight;
    const rail = SchematicView.railWidth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        4,
        AppSizes.gutter,
        24,
      ),
      children: [
        SegmentedButton<Direction>(
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
          selected: {_direction},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _direction = v.first),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: h * n,
            child: Stack(
              children: [
                // The red rail.
                PositionedDirectional(
                  start: rail / 2 - 3,
                  top: h / 2,
                  height: h * (n - 1),
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: t.line1,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
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
                      nextTime: () {
                        if (tt.isEndOfLine(idx, _direction)) return null;
                        final d = engine.nextDeparture(idx, _direction, now);
                        return d == null ? null : fmt.clock(d.time);
                      }(),
                      persian: fa,
                      onTap: () => context.push(
                        Routes.stationTimetable(tt.stations[idx].id),
                      ),
                    ),
                  ),
                for (final p in positions)
                  PositionedDirectional(
                    start: rail / 2 - 13,
                    top: (rowOf[p.fromIndex]! + p.progress) * h + h / 2 - 13,
                    child: Semantics(
                      label: l.arriving,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.surface, width: 2),
                        ),
                        child: Icon(
                          LucideIcons.trainFront,
                          size: 14,
                          color: t.onPrimary,
                        ),
                      ),
                    ),
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

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.timetable,
    required this.isSelected,
    required this.isArriving,
    required this.nextTime,
    required this.persian,
    required this.onTap,
  });

  final Station station;
  final Timetable timetable;
  final bool isSelected;
  final bool isArriving;
  final String? nextTime;
  final bool persian;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final terminal =
        station.index == 0 || station.index == timetable.stationCount - 1;
    final dot = station.isHub ? 24.0 : (terminal ? 20.0 : 16.0);
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: SchematicView.railWidth,
            child: Center(
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: terminal ? t.line1 : t.surface,
                  border: Border.all(
                    color: isSelected ? t.primary : t.line1,
                    width: station.isHub ? 5 : 3.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                    fontWeight: station.isHub || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: station.isHub ? 16 : 15,
                  ),
                ),
                if (isSelected || isArriving || station.isHub)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (isSelected)
                          _Tag(l.youAreHere, t.primarySoft, t.primary),
                        if (isArriving)
                          _Tag(l.arriving, t.successSoft, t.success),
                        if (station.isHub) _Tag(l.hub, t.line1Soft, t.line1),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Text(
              nextTime ?? '—',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: nextTime == null ? t.fgMuted : t.fg,
              ),
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Text(
      label,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
