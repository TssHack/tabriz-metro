import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
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
      backgroundColor: context.tokens.bg,
      appBar: AppBar(title: Text(l.navMap)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              0,
              AppSizes.gutter,
              10,
            ),
            child: PillToggle<MapMode>(
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
              options: [
                (MapMode.schematic, l.schematic, LucideIcons.trainTrack),
                (MapMode.city, l.city, LucideIcons.map),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_mode) {
                MapMode.schematic => const SchematicView(
                  key: ValueKey('schematic'),
                ),
                MapMode.city => const CityMapView(key: ValueKey('city')),
              },
            ),
          ),
        ],
      ),
    );
  }
}
