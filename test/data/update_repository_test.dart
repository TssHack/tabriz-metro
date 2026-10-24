import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabriz_metro/core/utils/format.dart';
import 'package:tabriz_metro/data/repositories/update_repository.dart';
import 'package:tabriz_metro/domain/update/releases.dart';

void main() {
  final release = Release.fromJson({
    'tag_name': 'v1.0.0',
    'assets': [
      {'name': 'a.apk', 'size': 10, 'browser_download_url': 'https://x/a.apk'},
      {
        'name': 'a.apk.sha256',
        'size': 64,
        'browser_download_url': 'https://x/a.apk.sha256',
      },
    ],
  });

  test('parses releases on 200', () async {
    final repo = UpdateRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'tag_name': 'v0.2.0', 'prerelease': false, 'assets': <Object>[]},
          ]),
          200,
        ),
      ),
    );
    final rs = await repo.fetchReleases();
    expect(rs.single.tagName, 'v0.2.0');
  });

  test('404 means no releases yet', () async {
    final repo = UpdateRepository(
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await repo.fetchReleases(), isEmpty);
  });

  test('rate limit is reported', () async {
    final repo = UpdateRepository(
      client: MockClient(
        (_) async =>
            http.Response('', 403, headers: {'x-ratelimit-remaining': '0'}),
      ),
    );
    expect(
      repo.fetchReleases(),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.kind,
          'kind',
          UpdateErrorKind.rateLimited,
        ),
      ),
    );
  });

  test('network errors are reported as offline', () async {
    final repo = UpdateRepository(
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    expect(
      repo.fetchReleases(),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.kind,
          'kind',
          UpdateErrorKind.offline,
        ),
      ),
    );
  });

  test('reads the expected checksum from the .sha256 asset', () async {
    final hash = 'ab' * 32;
    final repo = UpdateRepository(
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://x/a.apk.sha256');
        return http.Response('$hash  a.apk\n', 200);
      }),
    );
    expect(await repo.expectedChecksum(release, release.assets.first), hash);
  });

  test('missing checksum asset refuses the update', () async {
    final noSum = Release.fromJson({
      'tag_name': 'v1.0.0',
      'assets': [
        {'name': 'a.apk', 'size': 1, 'browser_download_url': 'https://x/a'},
      ],
    });
    final repo = UpdateRepository(
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(
      repo.expectedChecksum(noSum, noSum.assets.first),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.kind,
          'kind',
          UpdateErrorKind.noChecksum,
        ),
      ),
    );
  });

  test('Fmt formats digits, distance and sizes', () {
    const fa = Fmt(persianDigits: true);
    const en = Fmt(persianDigits: false);
    expect(fa.digits(12), '۱۲');
    expect(en.clock(DateTime(2026, 1, 1, 7, 5)), '07:05');
    expect(en.distance(437), (value: '440', km: false));
    expect(en.distance(1530), (value: '1.5', km: true));
    expect(en.bytes(2048), '2 KB');
    expect(en.bytes(5 * 1024 * 1024), '5.0 MB');
    expect(fa.minutes(355), '۰۵:۵۵');
  });
}
