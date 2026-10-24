import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/persian.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import 'station_widgets.dart';

/// Bottom sheet listing stations with search; returns the chosen station.
Future<Station?> showStationPicker(
  BuildContext context, {
  String? title,
  String? selectedId,
}) => showModalBottomSheet<Station>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _StationPicker(title: title, selectedId: selectedId),
  ),
);

class _StationPicker extends ConsumerStatefulWidget {
  const _StationPicker({this.title, this.selectedId});

  final String? title;
  final String? selectedId;

  @override
  ConsumerState<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends ConsumerState<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final tt = ref.watch(timetableProvider);
    final fa = ref.watch(
      settingsProvider.select((s) => s.languageCode == 'fa'),
    );
    final stations = tt.stations
        .where(
          (s) =>
              searchMatches(s.nameFa, _query) ||
              searchMatches(s.nameEn, _query),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            widget.title ?? l.chooseStation,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: l.searchStations,
              prefixIcon: const Icon(LucideIcons.search, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: stations.isEmpty
              ? Center(
                  child: Text(l.noResults, style: TextStyle(color: t.fgMuted)),
                )
              : ListView.builder(
                  itemCount: stations.length,
                  itemBuilder: (context, i) {
                    final s = stations[i];
                    final selected = s.id == widget.selectedId;
                    return ListTile(
                      leading: StationDot(station: s, timetable: tt),
                      title: Text(
                        s.name(persian: fa),
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? Icon(LucideIcons.check, color: t.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
