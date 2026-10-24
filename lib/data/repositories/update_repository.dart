import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../domain/update/releases.dart';

enum UpdateErrorKind {
  offline,
  rateLimited,
  noApk,
  noChecksum,
  mismatch,
  other,
}

class UpdateException implements Exception {
  const UpdateException(this.kind, [this.message = '']);

  final UpdateErrorKind kind;
  final String message;

  @override
  String toString() => 'UpdateException(${kind.name}: $message)';
}

/// Talks to the GitHub Releases API and downloads APKs.
class UpdateRepository {
  UpdateRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': AppConfig.userAgentPackage,
  };

  Future<List<Release>> fetchReleases() async {
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('${AppConfig.releasesApi}?per_page=30'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    } on TimeoutException {
      throw const UpdateException(UpdateErrorKind.offline, 'timeout');
    }
    if (res.statusCode == 403 || res.statusCode == 429) {
      if (res.headers['x-ratelimit-remaining'] == '0' ||
          res.statusCode == 429) {
        throw const UpdateException(UpdateErrorKind.rateLimited);
      }
    }
    if (res.statusCode == 404) return const []; // repo has no releases yet
    if (res.statusCode != 200) {
      throw UpdateException(UpdateErrorKind.other, 'HTTP ${res.statusCode}');
    }
    return parseReleases(utf8.decode(res.bodyBytes));
  }

  Future<String> fetchText(String url) async {
    try {
      final res = await _client
          .get(
            Uri.parse(url),
            headers: {'User-Agent': AppConfig.userAgentPackage},
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw UpdateException(UpdateErrorKind.other, 'HTTP ${res.statusCode}');
      }
      return utf8.decode(res.bodyBytes);
    } on SocketException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    }
  }

  /// Expected SHA-256 for [apk], from `<apk>.sha256` or `checksums.txt`.
  Future<String> expectedChecksum(Release release, ReleaseAsset apk) async {
    final asset = checksumAssetFor(release, apk);
    if (asset == null) throw const UpdateException(UpdateErrorKind.noChecksum);
    final hash = parseChecksumFile(
      await fetchText(asset.downloadUrl),
      apk.name,
    );
    if (hash == null) throw const UpdateException(UpdateErrorKind.noChecksum);
    return hash;
  }

  /// Downloads [asset] to a temporary file, reporting progress 0..1, and
  /// returns it once its SHA-256 equals [expectedSha256].
  Future<File> downloadVerified(
    ReleaseAsset asset,
    String expectedSha256, {
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${asset.name}');
    final req = http.Request('GET', Uri.parse(asset.downloadUrl))
      ..headers['User-Agent'] = AppConfig.userAgentPackage;
    final http.StreamedResponse res;
    try {
      res = await _client.send(req);
    } on SocketException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw UpdateException(UpdateErrorKind.offline, e.message);
    }
    if (res.statusCode != 200) {
      throw UpdateException(UpdateErrorKind.other, 'HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? asset.size;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    onVerifying?.call();
    final actual = await sha256OfStream(file.openRead());
    if (!checksumMatches(actual, expectedSha256)) {
      await file.delete().catchError((Object _) => file);
      throw UpdateException(UpdateErrorKind.mismatch, actual);
    }
    return file;
  }
}
