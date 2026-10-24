import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'semver.dart';

enum UpdateChannel {
  stable,
  beta;

  static UpdateChannel fromName(String? name) =>
      name == 'beta' ? UpdateChannel.beta : UpdateChannel.stable;
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
  });

  final String name;
  final int size;
  final String downloadUrl;
}

/// A GitHub release, as returned by `GET /repos/{owner}/{repo}/releases`.
class Release {
  const Release({
    required this.tagName,
    required this.name,
    required this.body,
    required this.prerelease,
    required this.draft,
    required this.htmlUrl,
    required this.assets,
    this.publishedAt,
  });

  factory Release.fromJson(Map<String, dynamic> j) => Release(
    tagName: j['tag_name'] as String? ?? '',
    name: j['name'] as String? ?? '',
    body: j['body'] as String? ?? '',
    prerelease: j['prerelease'] as bool? ?? false,
    draft: j['draft'] as bool? ?? false,
    htmlUrl: j['html_url'] as String? ?? '',
    publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
    assets: [
      for (final a
          in (j['assets'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        ReleaseAsset(
          name: a['name'] as String? ?? '',
          size: a['size'] as int? ?? 0,
          downloadUrl: a['browser_download_url'] as String? ?? '',
        ),
    ],
  );

  final String tagName;
  final String name;
  final String body;
  final bool prerelease;
  final bool draft;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  SemVer? get version => SemVer.tryParse(tagName);

  String get displayName => name.isNotEmpty ? name : tagName;

  ReleaseAsset? assetNamed(String n) {
    for (final a in assets) {
      if (a.name == n) return a;
    }
    return null;
  }
}

List<Release> parseReleases(String json) => [
  for (final r
      in (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>())
    Release.fromJson(r),
];

/// Picks the newest release newer than [current] for [channel]:
/// stable considers only non-prerelease releases, beta considers both.
/// Drafts, unparsable tags and [skippedVersion] are ignored.
Release? selectUpdate(
  Iterable<Release> releases, {
  required SemVer current,
  required UpdateChannel channel,
  String? skippedVersion,
}) {
  final skipped = skippedVersion == null
      ? null
      : SemVer.tryParse(skippedVersion);
  Release? best;
  SemVer? bestVersion;
  for (final r in releases) {
    if (r.draft) continue;
    final v = r.version;
    if (v == null) continue;
    final isPre = r.prerelease || v.isPreRelease;
    if (channel == UpdateChannel.stable && isPre) continue;
    if (skipped != null && v == skipped) continue;
    if (!(v > current)) continue;
    if (bestVersion == null || v > bestVersion) {
      best = r;
      bestVersion = v;
    }
  }
  return best;
}

/// Picks the APK asset for a device supporting [abis] (preferred first):
/// `*-<abi>-release.apk` (split-per-abi), else a universal `*.apk`.
ReleaseAsset? pickApkAsset(Release release, {List<String> abis = const []}) {
  final apks = release.assets
      .where((a) => a.name.toLowerCase().endsWith('.apk'))
      .toList();
  if (apks.isEmpty) return null;
  for (final abi in abis) {
    for (final a in apks) {
      if (a.name.contains(abi)) return a;
    }
  }
  const knownAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
  for (final a in apks) {
    if (!knownAbis.any(a.name.contains)) return a; // universal
  }
  return abis.isEmpty ? apks.first : null;
}

/// Asset that carries the checksum for [apk]: `<apk>.sha256` first, then a
/// combined `checksums.txt` / `SHA256SUMS`.
ReleaseAsset? checksumAssetFor(Release release, ReleaseAsset apk) =>
    release.assetNamed('${apk.name}.sha256') ??
    release.assetNamed('checksums.txt') ??
    release.assetNamed('SHA256SUMS') ??
    release.assetNamed('sha256sums.txt');

final _hexRe = RegExp(r'\b([a-fA-F0-9]{64})\b');

/// Extracts the SHA-256 for [fileName] from a checksum file. Supports a bare
/// hash and the `sha256sum` format (`<hash>  <name>` / `<hash> *<name>`).
String? parseChecksumFile(String content, String fileName) {
  final lines = content
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  for (final line in lines) {
    final m = _hexRe.firstMatch(line);
    if (m == null) continue;
    final rest = line.substring(m.end).trim().replaceFirst(RegExp(r'^\*'), '');
    final base = rest.split('/').last;
    if (rest.isEmpty ? lines.length == 1 : base == fileName) {
      return m.group(1)!.toLowerCase();
    }
  }
  return null;
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

Future<String> sha256OfStream(Stream<List<int>> stream) async =>
    (await sha256.bind(stream).first).toString();

bool checksumMatches(String actual, String expected) =>
    actual.trim().toLowerCase() == expected.trim().toLowerCase();
