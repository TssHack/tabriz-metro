import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';

/// Line-1 station marker: terminals filled, hub larger, others outlined.
class StationDot extends StatelessWidget {
  const StationDot({
    super.key,
    required this.station,
    required this.timetable,
    this.highlight = false,
  });

  final Station station;
  final Timetable timetable;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final terminal =
        station.index == 0 || station.index == timetable.stationCount - 1;
    final size = station.isHub ? 20.0 : 14.0;
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: terminal || highlight ? t.line1 : t.surface,
            border: Border.all(
              color: highlight ? t.primary : t.line1,
              width: station.isHub ? 4 : 3,
            ),
          ),
        ),
      ),
    );
  }
}
