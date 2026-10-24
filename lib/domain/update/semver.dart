/// Minimal Semantic Versioning 2.0.0 parsing and precedence.
class SemVer implements Comparable<SemVer> {
  const SemVer(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = const [],
    this.build = '',
  });

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers, e.g. ["beta", "2"].
  final List<String> preRelease;
  final String build;

  bool get isPreRelease => preRelease.isNotEmpty;

  static final _re = RegExp(
    r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  /// Parses "1.2.3", "v1.2.3-beta.1", "1.2" (patch defaults to 0) and
  /// "1.2.3+45". Returns null when [input] is not a version.
  static SemVer? tryParse(String input) {
    final m = _re.firstMatch(input.trim());
    if (m == null) return null;
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3) ?? '0'),
      preRelease: m.group(4)?.split('.') ?? const [],
      build: m.group(5) ?? '',
    );
  }

  static SemVer parse(String input) =>
      tryParse(input) ??
      (throw FormatException('Not a semantic version', input));

  @override
  int compareTo(SemVer other) {
    for (final c in [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
    ]) {
      if (c != 0) return c;
    }
    // A release has higher precedence than any of its pre-releases.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    final len = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < len; i++) {
      final c = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (c != 0) return c;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    final ai = int.tryParse(a);
    final bi = int.tryParse(b);
    if (ai != null && bi != null) return ai.compareTo(bi);
    if (ai != null) return -1; // numeric identifiers sort lower
    if (bi != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(SemVer o) => compareTo(o) > 0;
  bool operator <(SemVer o) => compareTo(o) < 0;
  bool operator >=(SemVer o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() =>
      '$major.$minor.$patch'
      '${preRelease.isEmpty ? '' : '-${preRelease.join('.')}'}'
      '${build.isEmpty ? '' : '+$build'}';
}
