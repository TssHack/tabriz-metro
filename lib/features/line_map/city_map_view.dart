import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Zoom at which station names appear next to markers.
const _labelZoom = 13.2;

/// City map of Line 1 on CARTO basemaps (OpenStreetMap data) with the
/// nearest/selected station in a draggable bottom sheet.
class CityMapView extends ConsumerStatefulWidget {
  const CityMapView({super.key});

  @override
  ConsumerState<CityMapView> createState() => _CityMapViewState();
}

class _CityMapViewState extends ConsumerState<CityMapView>
    with TickerProviderStateMixin {
  final _map = MapController();
  late final LocationController _location;
  String? _focusedId;
  AnimationController? _camera;

  @override
  void initState() {
    super.initState();
    // Keep a reference: `ref` must not be used in dispose().
    _location = ref.read(locationProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _location.startTracking();
    });
  }

  @override
  void dispose() {
    _location.stopTracking();
    _camera?.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Smoothly moves the camera to [center]/[zoom].
  void _animateTo(LatLng center, double zoom) {
    final cam = _map.camera;
    final latTween = Tween(begin: cam.center.latitude, end: center.latitude);
    final lngTween = Tween(begin: cam.center.longitude, end: center.longitude);
    final zoomTween = Tween(begin: cam.zoom, end: zoom);
    _camera?.dispose();
    final c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    c.addListener(() {
      _map.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    });
    _camera = c..forward();
  }

  void _fitLine(List<LatLng> points) {
    final fit = CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 240),
    ).fit(_map.camera);
    _animateTo(fit.center, fit.zoom);
  }

  Future<void> _locateMe() async {
    if (!kIsWeb) HapticFeedback.selectionClick().ignore();
    if (!ref.read(locationProvider).granted) {
      await context.push(Routes.location);
      if (!mounted || !ref.read(locationProvider).granted) return;
      _location.startTracking();
    }
    final p = await _location.locate();
    if (p != null && mounted) {
      setState(() => _focusedId = null);
      _animateTo(_ll(p), 15);
    }
  }

  void _focus(Station s) {
    if (!kIsWeb) HapticFeedback.selectionClick().ignore();
    setState(() => _focusedId = s.id);
    _animateTo(_ll(s.location!), _map.camera.zoom.clamp(14, 17));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tt = ref.watch(timetableProvider);
    final location = ref.watch(locationProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final located = tt.stations.where((s) => s.location != null).toList();
    if (located.isEmpty) {
      return EmptyState(
        icon: LucideIcons.mapPinned,
        message: l.mapNoCoordinates,
      );
    }
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

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: shape,
              padding: const EdgeInsets.fromLTRB(40, 80, 40, 240),
            ),
            minZoom: 10,
            maxZoom: 18,
            backgroundColor: t.surface2,
            onTap: (_, _) => setState(() => _focusedId = null),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: dark
                  ? AppConfig.cartoDarkTileUrl
                  : AppConfig.cartoLightTileUrl,
              fallbackUrl: AppConfig.osmTileUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: AppConfig.userAgentPackage,
              maxNativeZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                // Soft glow under the line.
                Polyline(
                  points: shape,
                  color: t.line1.withValues(alpha: 0.25),
                  strokeWidth: 16,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                Polyline(
                  points: shape,
                  color: t.line1,
                  strokeWidth: 6,
                  borderColor: dark ? t.bg : Colors.white,
                  borderStrokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            ),
            if (location.position != null && (location.accuracy ?? 0) > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _ll(location.position!),
                    radius: location.accuracy!,
                    useRadiusInMeter: true,
                    color: t.primary.withValues(alpha: 0.12),
                    borderColor: t.primary.withValues(alpha: 0.3),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            _StationMarkers(
              stations: located,
              timetable: tt,
              focusedId: focused?.id,
              persian: fa,
              onTap: _focus,
            ),
            if (location.position != null)
              MarkerLayer(
                markers: [
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
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: t.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              showFlutterMapAttribution: false,
              attributions: [TextSourceAttribution(l.mapAttributionCarto)],
            ),
          ],
        ),
        PositionedDirectional(
          top: 12,
          end: 12,
          child: Column(
            children: [
              _MapButton(
                tooltip: l.myLocation,
                icon: LucideIcons.locateFixed,
                busy: location.loading,
                onPressed: _locateMe,
              ),
              const SizedBox(height: 8),
              _MapButton(
                tooltip: l.fitLine,
                icon: LucideIcons.scan,
                onPressed: () => _fitLine(shape),
              ),
              const SizedBox(height: 8),
              _MapButton(
                tooltip: l.zoomIn,
                icon: LucideIcons.plus,
                onPressed: () =>
                    _animateTo(_map.camera.center, _map.camera.zoom + 1),
              ),
              const SizedBox(height: 8),
              _MapButton(
                tooltip: l.zoomOut,
                icon: LucideIcons.minus,
                onPressed: () =>
                    _animateTo(_map.camera.center, _map.camera.zoom - 1),
              ),
            ],
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
        DraggableScrollableSheet(
          initialChildSize: 0.32,
          minChildSize: 0.14,
          maxChildSize: 0.75,
          snap: true,
          builder: (context, scroll) => Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: softShadow(context),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                  ),
                ),
                if (focused == null)
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: t.fgMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.locationUnavailable)),
                      TextButton(
                        onPressed: _locateMe,
                        child: Text(l.enableLocation),
                      ),
                    ],
                  )
                else
                  StationInfoPanel(
                    station: focused,
                    meters: focusedMeters,
                    isNearest: focused.id == nearest?.station.id,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: softShadow(context),
      ),
      child: Material(
        color: t.surface,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: t.fg),
        ),
      ),
    );
  }
}

/// Station markers with zoom-dependent labels and a pulsing focused marker.
class _StationMarkers extends StatelessWidget {
  const _StationMarkers({
    required this.stations,
    required this.timetable,
    required this.focusedId,
    required this.persian,
    required this.onTap,
  });

  final List<Station> stations;
  final Timetable timetable;
  final String? focusedId;
  final bool persian;
  final ValueChanged<Station> onTap;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final showLabels = zoom >= _labelZoom;
    return MarkerLayer(
      markers: [
        for (final s in stations)
          Marker(
            point: _ll(s.location!),
            width: showLabels ? 160 : 44,
            height: showLabels ? 70 : 44,
            child: _StationMarker(
              station: s,
              terminal: s.index == 0 || s.index == timetable.stationCount - 1,
              focused: s.id == focusedId,
              label: showLabels || s.id == focusedId
                  ? s.name(persian: persian)
                  : null,
              onTap: () => onTap(s),
            ),
          ),
      ],
    );
  }
}

class _StationMarker extends StatefulWidget {
  const _StationMarker({
    required this.station,
    required this.terminal,
    required this.focused,
    required this.label,
    required this.onTap,
  });

  final Station station;
  final bool terminal;
  final bool focused;
  final String? label;
  final VoidCallback onTap;

  @override
  State<_StationMarker> createState() => _StationMarkerState();
}

class _StationMarkerState extends State<_StationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_StationMarker old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.focused && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.focused && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final big = widget.station.isHub || widget.terminal || widget.focused;
    final size = big ? 22.0 : 16.0;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.focused || widget.terminal ? t.line1 : Colors.white,
        border: Border.all(
          color: widget.focused || widget.terminal ? Colors.white : t.line1,
          width: widget.station.isHub ? 5 : 4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: widget.station.nameFa,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.focused)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) => Container(
                        width: size + 24 * _pulse.value,
                        height: size + 24 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.line1.withValues(
                            alpha: 0.35 * (1 - _pulse.value),
                          ),
                        ),
                      ),
                    ),
                  dot,
                ],
              ),
            ),
            if (widget.label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: widget.focused
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: t.fg,
                  ),
                ),
              ),
          ],
        ),
      ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNearest)
          Text(
            l.nearestStation,
            style: TextStyle(color: t.fgMuted, fontSize: 12),
          ),
        Text(
          station.name(persian: fa),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        if (meters != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                icon: LucideIcons.mapPin,
                label: formatDistance(l, fmt, meters!),
              ),
              Pill(
                icon: LucideIcons.footprints,
                label: l.walkMinutes(fmt.digits(walk!)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
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
                final catchable = engine.nextDeparture(station.index, d, ready);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(AppRadii.cardSmall),
                  ),
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
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (i, dep) in next.indexed)
                            Pill(
                              label: fmt.clock(dep.time),
                              background: i == 0 ? t.primarySoft : t.surface,
                              foreground: i == 0 ? t.primary : t.fgMuted,
                            ),
                        ],
                      ),
                      if (walk != null && catchable != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l.catchTrainIfLeaveNow(fmt.clock(catchable.time))} (${l.estimated})',
                          style: TextStyle(color: t.success, fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (station.location != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openWalkingDirections(
                    station.location!.lat,
                    station.location!.lng,
                    label: station.nameEn,
                  ),
                  icon: const Icon(LucideIcons.footprints, size: 18),
                  label: Text(l.walkingDirections, maxLines: 1),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    context.push(Routes.tripFromTo(from: station.id)),
                icon: const Icon(LucideIcons.navigation, size: 18),
                label: Text(l.planTrip, maxLines: 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
