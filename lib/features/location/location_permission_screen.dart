import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/settings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'location_controller.dart';

/// Explains why location is needed before the system prompt is shown.
class LocationPermissionScreen extends ConsumerWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final loc = ref.watch(locationProvider);
    final blocked =
        loc.status == LocationStatus.deniedForever ||
        loc.status == LocationStatus.serviceDisabled;

    Future<void> allow() async {
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(locationExplained: true));
      final status = await ref.read(locationProvider.notifier).request();
      if (status == LocationStatus.granted && context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: t.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.mapPin, size: 40, color: t.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.locationTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              l.locationBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.fgMuted, height: 1.7),
            ),
            const SizedBox(height: 24),
            for (final (icon, text) in [
              (LucideIcons.locateFixed, l.locationPoint1),
              (LucideIcons.footprints, l.locationPoint2),
              (LucideIcons.bellRing, l.locationPoint3),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(icon, color: t.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            InfoBanner(
              icon: LucideIcons.shieldCheck,
              child: Text(l.locationPrivacy),
            ),
            if (blocked) ...[
              const SizedBox(height: 12),
              InfoBanner(
                warning: true,
                icon: LucideIcons.triangleAlert,
                child: Text(
                  loc.status == LocationStatus.serviceDisabled
                      ? l.locationServiceOff
                      : l.locationDeniedForever,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (blocked)
              FilledButton(
                onPressed: () async {
                  await ref.read(locationProvider.notifier).openSettings();
                },
                child: Text(l.openSettings),
              )
            else
              FilledButton(onPressed: allow, child: Text(l.locationAllow)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pop(), child: Text(l.notNow)),
          ],
        ),
      ),
    );
  }
}
