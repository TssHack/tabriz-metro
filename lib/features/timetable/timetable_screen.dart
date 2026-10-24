import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/schedule/schedule_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../stations/station_picker.dart';

enum _ChipState { past, next, future }

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key, this.stationId, this.standalone = false});

  /// Station to show; defaults to the selected station.
  final String? stationId;

  /// Pushed on top of the shell (shows a back button).
  final bool standalone;

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  ScheduleType? _type;
  Direction? _direction;
  String? _stationId;
  final _scroll = ScrollController();
  final _nextKey = GlobalKey();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _stationId = widget.stationId;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    final ctx = _nextKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final engine = ref.watch(engineProvider);
    final now = ref.watch(nowProvider);
    final fmt = ref.watch(formatProvider);
    final settings = ref.watch(settingsProvider);
    final fa = settings.languageCode == 'fa';
    final station =
        tt.stationById(_stationId ?? '') ??
        ref.watch<Station>(selectedStationProvider);
    final todayType = engine.scheduleTypeFor(now);
    final type = _type ?? todayType;
    final available = Direction.values
        .where((d) => !tt.isEndOfLine(station.index, d))
        .toList();
    final direction = available.contains(_direction)
        ? _direction!
        : available.first;
    final schedule = tt[type];
    final window = engine.serviceWindow(station.index, direction, type);
    final departures = engine.dayDepartures(
      station.index,
      direction,
      now,
      type: type,
    );
    final isToday = type == todayType;
    final nowMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    Departure? nextDep;
    if (isToday) {
      for (final d in departures) {
        if (!d.time.isBefore(nowMinute)) {
          nextDep = d;
          break;
        }
      }
    }

    // Group by hour.
    final byHour = <int, List<Departure>>{};
    for (final d in departures) {
      byHour.putIfAbsent(d.time.hour, () => []).add(d);
    }

    if (!_scrolled && nextDep != null) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }

    final fav = settings.isFavorite(station.id);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        leading: widget.standalone
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.button),
          onTap: () async {
            final s = await showStationPicker(context, selectedId: station.id);
            if (s != null) {
              setState(() {
                _stationId = s.id;
                _scrolled = false;
              });
              if (!widget.standalone) {
                ref.read(settingsProvider.notifier).selectStation(s.id);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(station.name(persian: fa))),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: fav ? l.unfavorite : l.favorite,
            onPressed: () =>
                ref.read(settingsProvider.notifier).toggleFavorite(station.id),
            icon: Icon(LucideIcons.star, color: fav ? t.warning : t.fgMuted),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          4,
          AppSizes.gutter,
          24,
        ),
        children: [
          SegmentedButton<ScheduleType>(
            segments: [
              ButtonSegment(
                value: ScheduleType.weekday,
                label: Text(l.weekday),
                icon: const Icon(LucideIcons.briefcase, size: 16),
              ),
              ButtonSegment(
                value: ScheduleType.holiday,
                label: Text(l.holiday),
                icon: const Icon(LucideIcons.sun, size: 16),
              ),
            ],
            selected: {type},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 10),
          SegmentedButton<Direction>(
            segments: [
              for (final d in Direction.values)
                ButtonSegment(
                  value: d,
                  enabled: available.contains(d),
                  label: Text(
                    l.towardStation(tt.terminalOf(d).name(persian: fa)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selected: {direction},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _direction = v.first;
              _scrolled = false;
            }),
          ),
          const SizedBox(height: 14),
          InfoBanner(
            icon: LucideIcons.info,
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  '${l.headway}: ${l.headwayEvery(fmt.digits(schedule.headwayMinutes))}',
                ),
                if (window != null) ...[
                  Text('${l.firstTrain}: ${fmt.minutes(window.first)}'),
                  Text('${l.lastTrain}: ${fmt.minutes(window.last)}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in byHour.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(
                l.hourLabel(fmt.digits(entry.key.toString().padLeft(2, '0'))),
                style: TextStyle(
                  color: t.fgMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in entry.value)
                  _TimeChip(
                    key: identical(d, nextDep) ? _nextKey : null,
                    label: fmt.clock(d.time),
                    state: !isToday
                        ? _ChipState.future
                        : identical(d, nextDep)
                        ? _ChipState.next
                        : d.time.isBefore(nowMinute)
                        ? _ChipState.past
                        : _ChipState.future,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l.estimatedNote,
            style: TextStyle(color: t.fgMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({super.key, required this.label, required this.state});

  final String label;
  final _ChipState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg, border) = switch (state) {
      _ChipState.past => (t.surface2, t.fgMuted, t.surface2),
      _ChipState.next => (t.primary, t.onPrimary, t.primary),
      _ChipState.future => (t.surface, t.fg, t.border),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: state == _ChipState.next
              ? FontWeight.w800
              : FontWeight.w500,
          decoration: state == _ChipState.past
              ? TextDecoration.lineThrough
              : null,
          decorationColor: t.fgMuted,
        ),
      ),
    );
  }
}
