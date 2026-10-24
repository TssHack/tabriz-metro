import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/l10n_format.dart';
import '../../core/utils/persian.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/geo/geo.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';
import 'station_widgets.dart';

enum _Filter { all, favorites, nearby }

class StationsScreen extends ConsumerStatefulWidget {
  const StationsScreen({super.key});

  @override
  ConsumerState<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends ConsumerState<StationsScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  Future<void> _selectNearby() async {
    final loc = ref.read(locationProvider);
    if (!loc.granted) {
      await context.push(Routes.location);
      if (!ref.read(locationProvider).granted) return;
    } else if (loc.position == null) {
      await ref.read(locationProvider.notifier).locate();
    }
    if (mounted) setState(() => _filter = _Filter.nearby);
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
    final location = ref.watch(locationProvider);
    final fa = settings.languageCode == 'fa';

    final distances = <String, double>{};
    if (location.position != null) {
      for (final d in stationsByDistance(tt.stations, location.position!)) {
        distances[d.station.id] = d.meters;
      }
    }

    var stations = tt.stations
        .where(
          (s) =>
              searchMatches(s.nameFa, _query) ||
              searchMatches(s.nameEn, _query),
        )
        .toList();
    switch (_filter) {
      case _Filter.all:
        break;
      case _Filter.favorites:
        stations = stations.where((s) => settings.isFavorite(s.id)).toList();
      case _Filter.nearby:
        stations = stations.where((s) => distances.containsKey(s.id)).toList()
          ..sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
        stations = stations.take(5).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.navStations)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.searchStations,
                prefixIcon: const Icon(LucideIcons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
              children: [
                for (final (f, label, icon) in [
                  (_Filter.all, l.filterAll, LucideIcons.list),
                  (_Filter.favorites, l.filterFavorites, LucideIcons.star),
                  (_Filter.nearby, l.filterNearby, LucideIcons.locateFixed),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => f == _Filter.nearby
                          ? _selectNearby()
                          : setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: stations.isEmpty
                ? EmptyState(
                    icon: _filter == _Filter.favorites
                        ? LucideIcons.star
                        : LucideIcons.search,
                    message: _filter == _Filter.favorites
                        ? l.noFavorites
                        : l.noResults,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.gutter,
                      4,
                      AppSizes.gutter,
                      24,
                    ),
                    itemCount: stations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = stations[i];
                      final fav = settings.isFavorite(s.id);
                      final meters = distances[s.id];
                      String nextFor(Direction d) {
                        if (tt.isEndOfLine(s.index, d)) return '—';
                        final dep = engine.nextDeparture(s.index, d, now);
                        return dep == null ? '—' : fmt.clock(dep.time);
                      }

                      return AppCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .selectStation(s.id);
                          context.push(Routes.stationTimetable(s.id));
                        },
                        child: Row(
                          children: [
                            StationDot(station: s, timetable: tt),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.name(persian: fa),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (s.isHub) ...[
                                        const SizedBox(width: 6),
                                        Pill(
                                          label: l.hub,
                                          background: t.line1Soft,
                                          foreground: t.line1,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      _NextLabel(
                                        icon: LucideIcons.trainFront,
                                        text:
                                            '${tt.northTerminal.name(persian: fa)} ${nextFor(Direction.towardNoor)}',
                                      ),
                                      _NextLabel(
                                        icon: LucideIcons.trainFront,
                                        text:
                                            '${tt.southTerminal.name(persian: fa)} ${nextFor(Direction.towardEylGoli)}',
                                      ),
                                      if (meters != null)
                                        _NextLabel(
                                          icon: LucideIcons.footprints,
                                          text: formatDistance(l, fmt, meters),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: fav ? l.unfavorite : l.favorite,
                              onPressed: () => ref
                                  .read(settingsProvider.notifier)
                                  .toggleFavorite(s.id),
                              icon: Icon(
                                LucideIcons.star,
                                color: fav ? t.warning : t.fgMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NextLabel extends StatelessWidget {
  const _NextLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: t.fgMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: t.fgMuted, fontSize: 12.5)),
      ],
    );
  }
}
