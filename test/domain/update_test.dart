import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/domain/update/releases.dart';
import 'package:tabriz_metro/domain/update/semver.dart';

Map<String, dynamic> _release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  List<String> assets = const [],
}) => {
  'tag_name': tag,
  'name': 'Release $tag',
  'body': '## Changes',
  'prerelease': prerelease,
  'draft': draft,
  'html_url': 'https://github.com/tsshack/tabriz-metro/releases/tag/$tag',
  'published_at': '2026-10-01T10:00:00Z',
  'assets': [
    for (final a in assets)
      {'name': a, 'size': 1234, 'browser_download_url': 'https://dl/$a'},
  ],
};

void main() {
  group('SemVer', () {
    test('parses common forms', () {
      expect(SemVer.parse('1.2.3').toString(), '1.2.3');
      expect(SemVer.parse('v1.2.3-beta.1').preRelease, ['beta', '1']);
      expect(SemVer.parse('1.2').patch, 0);
      expect(SemVer.parse('1.2.3+45').build, '45');
      expect(SemVer.tryParse('latest'), isNull);
      expect(() => SemVer.parse('x'), throwsFormatException);
    });

    test('precedence follows semver 2.0', () {
      final ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '1.1.0',
        '2.0.0',
      ].map(SemVer.parse).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i] > ordered[i - 1], isTrue, reason: '${ordered[i]}');
      }
      expect(SemVer.parse('1.0.0+1') == SemVer.parse('1.0.0+2'), isTrue);
      expect(SemVer.parse('0.9.0') < SemVer.parse('0.10.0'), isTrue);
    });
  });

  group('selectUpdate', () {
    final releases = parseReleases(
      jsonEncode([
        _release('v0.3.0-beta.1', prerelease: true),
        _release('v0.2.1'),
        _release('v0.2.0'),
        _release('v0.4.0', draft: true),
        _release('nightly'),
      ]),
    );
    final current = SemVer.parse('0.2.0');

    test('stable picks newest non-prerelease', () {
      final r = selectUpdate(
        releases,
        current: current,
        channel: UpdateChannel.stable,
      );
      expect(r?.tagName, 'v0.2.1');
    });

    test('beta includes prereleases', () {
      final r = selectUpdate(
        releases,
        current: current,
        channel: UpdateChannel.beta,
      );
      expect(r?.tagName, 'v0.3.0-beta.1');
    });

    test('ignores drafts and returns null when up to date', () {
      expect(
        selectUpdate(
          releases,
          current: SemVer.parse('0.3.0'),
          channel: UpdateChannel.beta,
        ),
        isNull,
      );
    });

    test('a skipped version is not offered', () {
      expect(
        selectUpdate(
          releases,
          current: current,
          channel: UpdateChannel.stable,
          skippedVersion: '0.2.1',
        ),
        isNull,
      );
    });

    test(
      'tag with a pre-release suffix counts as beta even if not flagged',
      () {
        final rs = [Release.fromJson(_release('v1.0.0-rc.1'))];
        expect(
          selectUpdate(rs, current: current, channel: UpdateChannel.stable),
          isNull,
        );
        expect(UpdateChannel.fromName('beta'), UpdateChannel.beta);
        expect(UpdateChannel.fromName(null), UpdateChannel.stable);
      },
    );
  });

  group('assets', () {
    final split = Release.fromJson(
      _release(
        'v1.0.0',
        assets: [
          'app-armeabi-v7a-release.apk',
          'app-armeabi-v7a-release.apk.sha256',
          'app-arm64-v8a-release.apk',
          'app-arm64-v8a-release.apk.sha256',
          'app-x86_64-release.apk',
          'web.zip',
        ],
      ),
    );

    test('picks the APK for the preferred ABI', () {
      expect(
        pickApkAsset(split, abis: ['arm64-v8a', 'armeabi-v7a'])?.name,
        'app-arm64-v8a-release.apk',
      );
      expect(
        pickApkAsset(split, abis: ['armeabi-v7a'])?.name,
        'app-armeabi-v7a-release.apk',
      );
      expect(pickApkAsset(split, abis: ['mips']), isNull);
    });

    test('falls back to a universal APK', () {
      final r = Release.fromJson(
        _release('v1', assets: ['app-release.apk', 'checksums.txt']),
      );
      final apk = pickApkAsset(r, abis: ['arm64-v8a'])!;
      expect(apk.name, 'app-release.apk');
      expect(checksumAssetFor(r, apk)?.name, 'checksums.txt');
      expect(pickApkAsset(Release.fromJson(_release('v1'))), isNull);
    });

    test('per-file checksum asset is preferred', () {
      final apk = split.assetNamed('app-arm64-v8a-release.apk')!;
      expect(
        checksumAssetFor(split, apk)?.name,
        'app-arm64-v8a-release.apk.sha256',
      );
    });
  });

  group('checksums', () {
    final hash = sha256Hex(utf8.encode('hello'));

    test('sha256 of known input', () {
      expect(
        hash,
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });

    test('stream hashing equals byte hashing', () async {
      final h = await sha256OfStream(
        Stream.fromIterable([utf8.encode('hel'), utf8.encode('lo')]),
      );
      expect(h, hash);
    });

    test('parses bare hash and sha256sum formats', () {
      expect(parseChecksumFile('$hash\n', 'a.apk'), hash);
      expect(parseChecksumFile('${hash.toUpperCase()}  a.apk', 'a.apk'), hash);
      final multi = '${'0' * 64}  other.apk\n$hash *build/out/a.apk\n';
      expect(parseChecksumFile(multi, 'a.apk'), hash);
      expect(parseChecksumFile(multi, 'missing.apk'), isNull);
      expect(parseChecksumFile('not a hash', 'a.apk'), isNull);
    });

    test('verification compares case-insensitively', () {
      expect(checksumMatches(hash, hash.toUpperCase()), isTrue);
      expect(checksumMatches(hash, '0' * 64), isFalse);
    });
  });
}
