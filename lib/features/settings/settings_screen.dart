import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/geo/geo.dart';
import '../../domain/update/releases.dart';
import '../../l10n/generated/app_localizations.dart';
import '../stations/station_picker.dart';
import '../update/update_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final tt = ref.watch(timetableProvider);
    final fmt = ref.watch(formatProvider);
    final version = ref.watch(appVersionProvider).value ?? '…';
    final fa = s.languageCode == 'fa';

    Widget seg<T>(List<(T, String)> options, T selected, ValueChanged<T> on) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              segments: [
                for (final (v, label) in options)
                  ButtonSegment(value: v, label: Text(label)),
              ],
              selected: {selected},
              showSelectedIcon: false,
              onSelectionChanged: (v) => on(v.first),
            ),
          ),
        );

    Widget label(String text, IconData icon) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.fgMuted),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          32,
        ),
        children: [
          SectionTitle(l.appearance),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                label(l.theme, LucideIcons.sunMoon),
                seg(
                  [
                    (ThemeMode.system, l.themeSystem),
                    (ThemeMode.light, l.themeLight),
                    (ThemeMode.dark, l.themeDark),
                  ],
                  s.themeMode,
                  (v) => n.update((x) => x.copyWith(themeMode: v)),
                ),
                label(l.textSize, LucideIcons.type),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Slider(
                    value: s.textScale,
                    min: 0.85,
                    max: 1.3,
                    divisions: 3,
                    label: fmt.digits('${(s.textScale * 100).round()}%'),
                    onChanged: (v) => n.update((x) => x.copyWith(textScale: v)),
                  ),
                ),
                label(l.digits, LucideIcons.hash),
                seg(
                  [(true, '${l.digitsFa} ۱۲۳'), (false, '${l.digitsEn} 123')],
                  s.persianDigits,
                  (v) => n.update((x) => x.copyWith(persianDigits: v)),
                ),
                label(l.language, LucideIcons.languages),
                seg(
                  [('fa', 'فارسی'), ('en', 'English')],
                  s.languageCode,
                  (v) => n.update(
                    (x) =>
                        x.copyWith(languageCode: v, persianDigits: v == 'fa'),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(l.travel),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.mapPin),
                  title: Text(l.defaultStation),
                  subtitle: Text(
                    tt
                            .stationById(s.defaultStationId ?? '')
                            ?.name(persian: fa) ??
                        l.none,
                  ),
                  trailing: const Icon(LucideIcons.chevronRightDir, size: 18),
                  onTap: () async {
                    final st = await showStationPicker(
                      context,
                      title: l.defaultStation,
                      selectedId: s.defaultStationId,
                    );
                    if (st != null) {
                      n.update(
                        (x) => x.copyWith(
                          defaultStationId: () => st.id,
                          selectedStationId: st.id,
                        ),
                      );
                    }
                  },
                ),
                label(l.walkingSpeed, LucideIcons.footprints),
                seg(
                  [
                    (WalkingSpeed.slow, l.speedSlow),
                    (WalkingSpeed.normal, l.speedNormal),
                    (WalkingSpeed.fast, l.speedFast),
                  ],
                  s.walkingSpeed,
                  (v) => n.update((x) => x.copyWith(walkingSpeed: v)),
                ),
                label(l.schedule, LucideIcons.calendarDays),
                seg(
                  [
                    (ScheduleMode.auto, l.scheduleAuto),
                    (ScheduleMode.weekday, l.weekday),
                    (ScheduleMode.holiday, l.holiday),
                  ],
                  s.scheduleMode,
                  (v) => n.update((x) => x.copyWith(scheduleMode: v)),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.bell),
                  title: Text(l.notifications),
                  subtitle: Text(l.automations),
                  trailing: const Icon(LucideIcons.chevronRightDir, size: 18),
                  onTap: () => context.push(Routes.automations),
                ),
              ],
            ),
          ),
          SectionTitle(l.updates),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.refreshCw),
                  title: Text(l.autoCheckUpdates),
                  value: s.autoCheckUpdates,
                  onChanged: (v) =>
                      n.update((x) => x.copyWith(autoCheckUpdates: v)),
                ),
                label(l.updateChannel, LucideIcons.gitBranch),
                seg(
                  [
                    (UpdateChannel.stable, l.channelStable),
                    (UpdateChannel.beta, l.channelBeta),
                  ],
                  s.updateChannel,
                  (v) => n.update((x) => x.copyWith(updateChannel: v)),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.info),
                  title: Text(l.currentVersion),
                  subtitle: Text(fmt.digits(version)),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(updateControllerProvider.notifier).check();
                      context.push(Routes.update);
                    },
                    child: Text(l.checkNow),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(l.data),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.database),
                  title: Text(l.dataVersion),
                  subtitle: Text(fmt.digits(tt.dataVersion)),
                ),
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: t.line1),
                  title: Text(l.clearFavorites),
                  enabled: s.favorites.isNotEmpty,
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: Text(l.clearFavoritesConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(l.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(l.confirm),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) {
                      n.update((x) => x.copyWith(favorites: const []));
                    }
                  },
                ),
              ],
            ),
          ),
          SectionTitle(l.about),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(LucideIcons.heart),
              title: Text(l.about),
              trailing: const Icon(LucideIcons.chevronRightDir, size: 18),
              onTap: () => context.push(Routes.about),
            ),
          ),
        ],
      ),
    );
  }
}
