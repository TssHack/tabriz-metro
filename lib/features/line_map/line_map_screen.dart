import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import 'city_map_view.dart';
import 'schematic_view.dart';

enum MapMode { schematic, city }

class LineMapScreen extends ConsumerStatefulWidget {
  const LineMapScreen({super.key});

  @override
  ConsumerState<LineMapScreen> createState() => _LineMapScreenState();
}

class _LineMapScreenState extends ConsumerState<LineMapScreen> {
  MapMode _mode = MapMode.schematic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navMap),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: SegmentedButton<MapMode>(
              segments: [
                ButtonSegment(
                  value: MapMode.schematic,
                  label: Text(l.schematic),
                  icon: const Icon(LucideIcons.trainTrack, size: 16),
                ),
                ButtonSegment(
                  value: MapMode.city,
                  label: Text(l.city),
                  icon: const Icon(LucideIcons.map, size: 16),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
          ),
        ],
      ),
      body: switch (_mode) {
        MapMode.schematic => const SchematicView(),
        MapMode.city => const CityMapView(),
      },
      backgroundColor: context.tokens.bg,
    );
  }
}
