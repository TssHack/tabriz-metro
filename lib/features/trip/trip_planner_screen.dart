import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/l10n_format.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/geo/geo.dart';
import '../../domain/trip/trip_planner.dart';
import '../../l10n/generated/app_localizations.dart';
import '../automations/automation_controller.dart';
import '../location/location_controller.dart';
import '../stations/station_picker.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key, this.fromId, this.toId});

  final String? fromId;
  final String? toId;

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  /// null = current location.
  String? _fromId;
  String? _toId;
  bool _fromLocation = false;
  bool _showAllStops = false;

  @override
  void initState() {
    super.initState();
    _fromId = widget.fromId;
    _toId = widget.toId;
    final tt = ref.read(timetableProvider);
    _fromId ??= ref.read(selectedStationProvider).id;
    _toId ??= _fromId == tt.northTerminal.id
        ? tt.southTerminal.id
        : tt.northTerminal.id;
  }

  Future<void> _pickFrom() async {
    final s = await showStationPicker(
      context,
      title: l10n.from,
      selectedId: _fromId,
    );
    if (s != null) {
      setState(() {
        _fromId = s.id;
        _fromLocation = false;
      });
    }
  }

  Future<void> _pickTo() async {
    final s = await showStationPicker(
      context,
      title: l10n.to,
      selectedId: _toId,
    );
    if (s != null) setState(() => _toId = s.id);
  }

  Future<void> _useLocation() async {
    if (!ref.read(locationProvider).granted) {
      await context.push(Routes.location);
      if (!ref.read(locationProvider).granted) return;
    }
    await ref.read(locationProvider.notifier).locate();
    if (mounted) setState(() => _fromLocation = true);
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final engine = ref.watch(engineProvider);
    final now = ref.watch(nowProvider);
    final fmt = ref.watch(formatProvider);
    final settings = ref.watch(settingsProvider);
    final location = ref.watch(locationProvider);
    final fa = settings.languageCode == 'fa';

    Station? origin = tt.stationById(_fromId ?? '');
    double? walkMeters;
    if (_fromLocation && location.position != null) {
      final n = nearestStation(tt.stations, location.position!);
      if (n != null) {
        origin = n.station;
        walkMeters = n.meters;
      }
    }
    final dest = tt.stationById(_toId ?? '');
    final plan = origin == null || dest == null
        ? null
        : planTrip(
            engine: engine,
            origin: origin,
            destination: dest,
            now: now,
            walkMeters: walkMeters,
            speed: settings.walkingSpeed,
          );

    return Scaffold(
      appBar: AppBar(title: Text(l.tripPlanner)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.gutter),
        children: [
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _EndpointTile(
                        label: l.from,
                        icon: _fromLocation
                            ? LucideIcons.locateFixed
                            : LucideIcons.circleDot,
                        value: _fromLocation
                            ? '${l.currentLocation}${origin == null ? '' : ' · ${origin.name(persian: fa)}'}'
                            : origin?.name(persian: fa) ?? l.chooseStation,
                        onTap: _pickFrom,
                        trailing: IconButton(
                          tooltip: l.currentLocation,
                          onPressed: _useLocation,
                          icon: Icon(
                            LucideIcons.locateFixed,
                            color: _fromLocation ? t.primary : t.fgMuted,
                          ),
                        ),
                      ),
                      Divider(indent: 48, color: t.border),
                      _EndpointTile(
                        label: l.to,
                        icon: LucideIcons.mapPin,
                        value: dest?.name(persian: fa) ?? l.chooseStation,
                        onTap: _pickTo,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.swap,
                  onPressed: origin == null
                      ? null
                      : () => setState(() {
                          final from = origin!.id;
                          _fromId = _toId;
                          _toId = from;
                          _fromLocation = false;
                        }),
                  icon: const Icon(LucideIcons.arrowDownUp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (origin != null && dest != null && origin.id == dest.id)
            InfoBanner(icon: LucideIcons.info, child: Text(l.sameStation))
          else if (plan == null)
            InfoBanner(
              warning: true,
              icon: LucideIcons.circleAlert,
              child: Text(l.noTripFound),
            )
          else ...[
            _Summary(plan: plan, fmt: fmt),
            const SizedBox(height: 16),
            AppCard(
              child: _Timeline(
                plan: plan,
                fmt: fmt,
                persian: fa,
                terminalName: tt.terminalOf(plan.direction).name(persian: fa),
                showAll: _showAllStops,
                onToggle: () => setState(() => _showAllStops = !_showAllStops),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await ref
                    .read(automationControllerProvider)
                    .startTrip(plan);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok ? l.tripStarted : l.notificationsDenied),
                  ),
                );
              },
              icon: const Icon(LucideIcons.play, size: 18),
              label: Text(l.startTrip),
            ),
            const SizedBox(height: 8),
            Text(
              l.estimatedNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.fgMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: t.line1),
      title: Text(label, style: TextStyle(color: t.fgMuted, fontSize: 12)),
      subtitle: Text(
        value,
        style: TextStyle(
          color: t.fg,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      trailing: trailing,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.fmt});

  final TripPlan plan;
  final Fmt fmt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    Widget cell(String label, String value, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: t.fgMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color ?? t.fg,
            ),
          ),
        ],
      ),
    );
    return AppCard(
      color: t.primarySoft,
      child: Row(
        children: [
          cell(l.departure, fmt.clock(plan.boardAt), color: t.primary),
          cell(l.arrival, fmt.clock(plan.arrival), color: t.primary),
          cell(l.total, l.minutesValue(fmt.digits(plan.total.inMinutes))),
          cell(l.station, l.stopsCount(fmt.digits(plan.stopCount))),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.plan,
    required this.fmt,
    required this.persian,
    required this.terminalName,
    required this.showAll,
    required this.onToggle,
  });

  final TripPlan plan;
  final Fmt fmt;
  final bool persian;
  final String terminalName;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final steps = <_Step>[
      if (plan.walkMinutes > 0)
        _Step(
          icon: LucideIcons.footprints,
          color: t.fgMuted,
          time: fmt.clock(plan.startAt),
          title: l.walkToStation(plan.origin.name(persian: persian)),
          subtitle: [
            l.walkMinutes(fmt.digits(plan.walkMinutes)),
            if (plan.walkMeters != null)
              formatDistance(l, fmt, plan.walkMeters!),
          ].join(' · '),
        ),
      if (plan.wait.inMinutes > 0)
        _Step(
          icon: LucideIcons.timer,
          color: t.warning,
          time: fmt.clock(plan.arriveAtOrigin),
          title: l.waitForTrain,
          subtitle: l.minutesValue(fmt.digits(plan.wait.inMinutes)),
        ),
      _Step(
        icon: LucideIcons.trainFront,
        color: t.line1,
        time: fmt.clock(plan.boardAt),
        title: '${l.rideTrain} · ${l.towardStation(terminalName)}',
        subtitle:
            '${l.minutesValue(fmt.digits(plan.ride.inMinutes))} · ${l.stopsCount(fmt.digits(plan.stopCount))}',
      ),
    ];
    final middle = plan.stops.sublist(1, plan.stops.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in steps) _StepRow(step: s),
        if (middle.isNotEmpty) ...[
          if (showAll)
            for (final stop in middle)
              _StepRow(
                step: _Step(
                  icon: LucideIcons.circleDot,
                  color: t.line1,
                  time: fmt.clock(stop.time),
                  title: stop.station.name(persian: persian),
                  small: true,
                ),
              ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                showAll ? LucideIcons.chevronDown : LucideIcons.chevronRightDir,
                size: 16,
              ),
              label: Text(l.stopsCount(fmt.digits(middle.length))),
            ),
          ),
        ],
        _StepRow(
          last: true,
          step: _Step(
            icon: LucideIcons.mapPin,
            color: t.success,
            time: fmt.clock(plan.arrival),
            title: l.arriveAt(plan.destination.name(persian: persian)),
            subtitle: l.estimated,
          ),
        ),
      ],
    );
  }
}

class _Step {
  const _Step({
    required this.icon,
    required this.color,
    required this.time,
    required this.title,
    this.subtitle,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final String time;
  final String title;
  final String? subtitle;
  final bool small;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, this.last = false});

  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              step.time,
              style: TextStyle(
                fontWeight: step.small ? FontWeight.w500 : FontWeight.w700,
                color: step.small ? t.fgMuted : t.fg,
                fontSize: step.small ? 12.5 : 14,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(step.icon, size: step.small ? 12 : 20, color: step.color),
                if (!last)
                  Expanded(child: Container(width: 2, color: t.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: step.small ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: step.small
                          ? FontWeight.w500
                          : FontWeight.w700,
                      fontSize: step.small ? 13 : 15,
                    ),
                  ),
                  if (step.subtitle != null)
                    Text(
                      step.subtitle!,
                      style: TextStyle(color: t.fgMuted, fontSize: 12.5),
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
