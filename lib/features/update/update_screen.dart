import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/links.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/update_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'update_controller.dart';

class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phase = ref.read(updateControllerProvider).phase;
      if (phase == UpdatePhase.idle || phase == UpdatePhase.error) {
        ref.read(updateControllerProvider.notifier).check();
      }
    });
  }

  String _errorText(AppLocalizations l, UpdateState s) => switch (s.error) {
    UpdateErrorKind.offline => l.offline,
    UpdateErrorKind.rateLimited => l.rateLimited,
    UpdateErrorKind.noApk => l.noApk,
    UpdateErrorKind.noChecksum => l.noChecksum,
    UpdateErrorKind.mismatch => l.checksumMismatch,
    _ => l.genericError(s.errorMessage),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final s = ref.watch(updateControllerProvider);
    final c = ref.read(updateControllerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final fmt = ref.watch(formatProvider);
    final r = s.release;

    return Scaffold(
      appBar: AppBar(title: Text(l.updateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.gutter),
        children: [
          AppCard(
            child: Row(
              children: [
                Icon(LucideIcons.info, color: t.fgMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(l.currentVersion)),
                Text(
                  fmt.digits(s.currentVersion ?? '…'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          switch (s.phase) {
            UpdatePhase.idle || UpdatePhase.checking => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l.checking),
                ],
              ),
            ),
            UpdatePhase.upToDate => EmptyState(
              icon: LucideIcons.shieldCheck,
              message: l.upToDate,
              action: OutlinedButton.icon(
                onPressed: c.check,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(l.checkNow),
              ),
            ),
            UpdatePhase.error => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoBanner(
                  warning: true,
                  icon: LucideIcons.triangleAlert,
                  child: Text(_errorText(l, s)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: c.check,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(l.retry),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      openExternal(r?.htmlUrl ?? AppConfig.releasesUrl),
                  icon: const Icon(LucideIcons.externalLink, size: 18),
                  label: Text(l.openReleasePage),
                ),
              ],
            ),
            _ when r != null => _ReleaseDetails(state: s),
            _ => const SizedBox.shrink(),
          },
          const SizedBox(height: 16),
          if (canSelfInstall)
            SwitchListTile(
              value: settings.wifiOnly,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update((x) => x.copyWith(wifiOnly: v)),
              title: Text(l.wifiOnly),
              secondary: const Icon(LucideIcons.wifi),
            ),
        ],
      ),
    );
  }
}

class _ReleaseDetails extends ConsumerWidget {
  const _ReleaseDetails({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final fmt = ref.watch(formatProvider);
    final c = ref.read(updateControllerProvider.notifier);
    final r = state.release!;
    final published = r.publishedAt?.toLocal();
    final dateText = published == null
        ? '—'
        : fmt.digits(JalaliDate.fromGregorian(published).toString());
    final busy =
        state.phase == UpdatePhase.downloading ||
        state.phase == UpdatePhase.verifying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: t.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.updateAvailable(fmt.digits(r.version.toString())),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: t.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    icon: LucideIcons.calendar,
                    label: '${l.date}: $dateText',
                  ),
                  if (state.apk != null)
                    Pill(
                      icon: LucideIcons.download,
                      label: '${l.size}: ${fmt.bytes(state.apk!.size)}',
                    ),
                  if (r.prerelease) Pill(label: l.channelBeta),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (canSelfInstall) ...[
          if (busy) ...[
            LinearProgressIndicator(
              value: state.phase == UpdatePhase.verifying
                  ? null
                  : state.progress,
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            const SizedBox(height: 8),
            Text(
              state.phase == UpdatePhase.verifying
                  ? l.verifying
                  : l.downloading(fmt.digits((state.progress * 100).round())),
              textAlign: TextAlign.center,
            ),
          ] else
            FilledButton.icon(
              onPressed: state.phase == UpdatePhase.readyToInstall
                  ? c.install
                  : () async {
                      final ok = await c.downloadAndInstall();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(l.needWifi)));
                      }
                    },
              icon: const Icon(LucideIcons.download, size: 18),
              label: Text(
                state.phase == UpdatePhase.readyToInstall
                    ? l.install
                    : l.downloadAndInstall,
              ),
            ),
        ] else
          FilledButton.icon(
            onPressed: () => openExternal(r.htmlUrl),
            icon: const Icon(LucideIcons.externalLink, size: 18),
            label: Text(l.openReleasePage),
          ),
        const SizedBox(height: 8),
        if (!busy)
          TextButton(onPressed: c.skipCurrent, child: Text(l.skipVersion)),
        SectionTitle(l.releaseNotes),
        AppCard(
          child: r.body.trim().isEmpty
              ? Text('—', style: TextStyle(color: t.fgMuted))
              : MarkdownBody(
                  data: r.body,
                  onTapLink: (_, href, _) {
                    if (href != null) openExternal(href);
                  },
                ),
        ),
      ],
    );
  }
}
