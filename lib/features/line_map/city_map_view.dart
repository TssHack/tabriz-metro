import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/l10n_format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/geo/geo.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

/// OpenStreetMap view of Line 1 with the nearest-station panel.
class CityMapView extends ConsumerStatefulWidget {
  const CityMapView({super.key});

  @override
  ConsumerState<CityMapView> createState() => _CityMapViewState();
}

class _CityMapViewState extends ConsumerState<CityMapView> {
  final _map = MapController();
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(locationProvider.notifier).startTracking();
    });
  }

  @override
  void deactivate() {
    ref.read(locationProvider.notifier).stopTracking();
    super.deactivate();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    final loc = ref.read(locationProvider);
    if (!loc.granted) {
      await context.push(Routes.location);
      if (!mounted || !ref.read(locationProvider).granted) return;
      ref.read(locationProvider.notifier).startTracking();
    }
    final p = await ref.read(locationProvider.notifier).locate();
    if (p != null && mounted) {
      setState(() => _focusedId = null);
      _map.move(_ll(p), 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final location = ref.watch(locationProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final located = tt.stations.where((s) => s.location != null).toList();
    final missing = located.length < tt.stationCount;
    final shape = tt.shape.isNotEmpty
        ? tt.shape.map(_ll).toList()
        : located.map((s) => _ll(s.location!)).toList();

    final nearest = location.position == null
        ? null
        : nearestStation(tt.stations, location.position!);
    final focused = tt.stationById(_focusedId ?? '') ?? nearest?.station;
    final focusedMeters = focused?.location == null || location.position == null
        ? null
        : haversineMeters(location.position!, focused!.location!);

    if (located.isEmpty) {
      return EmptyState(
        icon: LucideIcons.mapPinned,
        message: l.mapNoCoordinates,
      );
    }

    final bounds = LatLngBounds.fromPoints(
      located.map((s) => _ll(s.location!)).toList(),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 220),
            ),
            minZoom: 10,
            maxZoom: 18,
            onTap: (_, _) => setState(() => _focusedId = null),
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: AppConfig.userAgentPackage,
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: shape,
                  color: t.line1,
                  strokeWidth: 6,
                  borderColor: t.surface,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final s in located)
                  Marker(
                    point: _ll(s.location!),
                    width: 44,
                    height: 44,
                    child: Semantics(
                      button: true,
                      label: s.name(persian: fa),
                      child: GestureDetector(
                        onTap: () => setState(() => _focusedId = s.id),
                        child: Center(
                          child: Container(
                            width: s.isHub ? 22 : 16,
                            height: s.isHub ? 22 : 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.id == focused?.id ? t.line1 : t.surface,
                              border: Border.all(color: t.line1, width: 3.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (location.position != null)
                  Marker(
                    point: _ll(location.position!),
                    width: 26,
                    height: 26,
                    child: Semantics(
                      label: l.myLocation,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.primary,
                          border: Border.all(color: t.surface, width: 4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(l.mapAttribution)],
            ),
          ],
        ),
        PositionedDirectional(
          top: 12,
          end: 12,
          child: Material(
            color: t.surface,
            shape: const CircleBorder(),
            elevation: 1,
            child: IconButton(
              tooltip: l.myLocation,
              onPressed: _locateMe,
              icon: location.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(LucideIcons.locateFixed, color: t.primary),
            ),
          ),
        ),
        if (missing)
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 72,
            child: InfoBanner(
              warning: true,
              icon: LucideIcons.circleAlert,
              child: Text(l.mapNoCoordinates),
            ),
          ),
        PositionedDirectional(
          start: 12,
          end: 12,
          bottom: 12,
          child: focused == null
              ? AppCard(
                  child: Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: t.fgMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.locationUnavailable)),
                      TextButton(
                        onPressed: _locateMe,
                        child: Text(l.enableLocation),
                      ),
                    ],
                  ),
                )
              : StationInfoPanel(
                  station: focused,
                  meters: focusedMeters,
                  isNearest: focused.id == nearest?.station.id,
                ),
        ),
      ],
    );
  }
}

/// Nearest/selected station details: distance, walk time and next trains.
class StationInfoPanel extends ConsumerWidget {
  const StationInfoPanel({
    super.key,
    required this.station,
    required this.meters,
    required this.isNearest,
  });

  final Station station;
  final double? meters;
  final bool isNearest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final engine = ref.watch(engineProvider);
    final now = ref.watch(nowProvider);
    final fmt = ref.watch(formatProvider);
    final settings = ref.watch(settingsProvider);
    final fa = settings.languageCode == 'fa';
    final walk = meters == null
        ? null
        : walkMinutes(meters!, settings.walkingSpeed);
    final ready = now.add(Duration(minutes: walk ?? 0));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNearest)
            Text(
              l.nearestStation,
              style: TextStyle(color: t.fgMuted, fontSize: 12),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  station.name(persian: fa),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (meters != null) ...[
                Pill(
                  icon: LucideIcons.mapPin,
                  label: formatDistance(l, fmt, meters!),
                ),
                const SizedBox(width: 6),
                Pill(
                  icon: LucideIcons.footprints,
                  label: l.walkMinutes(fmt.digits(walk!)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final d in Direction.values)
            if (!tt.isEndOfLine(station.index, d))
              Builder(
                builder: (context) {
                  final next = engine.nextDepartures(
                    station.index,
                    d,
                    now,
                    count: 3,
                  );
                  final catchable = engine.nextDeparture(
                    station.index,
                    d,
                    ready,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.trainFront,
                              size: 16,
                              color: t.line1,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.towardStation(
                                  tt.terminalOf(d).name(persian: fa),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            for (final dep in next) ...[
                              const SizedBox(width: 6),
                              Text(
                                fmt.clock(dep.time),
                                style: TextStyle(
                                  color: identical(dep, next.first)
                                      ? t.primary
                                      : t.fgMuted,
                                  fontWeight: identical(dep, next.first)
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (walk != null && catchable != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 22,
                              top: 2,
                            ),
                            child: Text(
                              '${l.catchTrainIfLeaveNow(fmt.clock(catchable.time))} (${l.estimated})',
                              style: TextStyle(
                                color: t.success,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          Row(
            children: [
              if (station.location != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openWalkingDirections(
                      station.location!.lat,
                      station.location!.lng,
                      label: station.nameEn,
                    ),
                    icon: const Icon(LucideIcons.footprints, size: 18),
                    label: Text(l.walkingDirections),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(Routes.tripFromTo(from: station.id)),
                  icon: const Icon(LucideIcons.navigation, size: 18),
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
