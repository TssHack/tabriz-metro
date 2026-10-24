import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../update/update_controller.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final fmt = ref.watch(formatProvider);
    final version = ref.watch(appVersionProvider).value ?? '…';

    Widget link(IconData icon, String title, String url, {String? subtitle}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, textDirection: TextDirection.ltr),
          trailing: const Icon(LucideIcons.externalLink, size: 16),
          onTap: () => openExternal(url),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          8,
          AppSizes.gutter,
          32,
        ),
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/logo/logo-red.svg',
              width: 96,
              height: 96,
              semanticsLabel: l.appTitle,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.appTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            l.versionLabel(fmt.digits(version)),
            textAlign: TextAlign.center,
            style: TextStyle(color: t.fgMuted),
          ),
          const SizedBox(height: 8),
          Center(
            child: Pill(
              icon: LucideIcons.code,
              label: l.openSource,
              background: t.successSoft,
              foreground: t.success,
            ),
          ),
          SectionTitle(l.developer),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.primarySoft,
                    child: Icon(LucideIcons.user, color: t.primary),
                  ),
                  title: Text(
                    l.developerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    AppConfig.developerHandle,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                link(
                  LucideIcons.globe,
                  l.website,
                  AppConfig.developerWebsite,
                  subtitle: 'ehsanfazli.ir',
                ),
                link(
                  LucideIcons.codeXml,
                  l.github,
                  AppConfig.developerGithub,
                  subtitle: 'github.com/tsshack',
                ),
              ],
            ),
          ),
          SectionTitle(l.project),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                link(LucideIcons.codeXml, l.sourceCode, AppConfig.repoUrl),
                link(LucideIcons.bug, l.reportIssue, AppConfig.issuesNewUrl),
                link(LucideIcons.star, l.starProject, AppConfig.repoUrl),
                ListTile(
                  leading: const Icon(LucideIcons.share2),
                  title: Text(l.shareApp),
                  onTap: () => SharePlus.instance.share(
                    ShareParams(text: l.shareText(AppConfig.repoUrl)),
                  ),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.scrollText),
                  title: Text(l.licenses),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l.appTitle,
                    applicationVersion: version,
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(l.dataSource),
          InfoBanner(icon: LucideIcons.database, child: Text(l.dataSourceBody)),
        ],
      ),
    );
  }
}
