/// Project-wide constants. The GitHub repository is configured only here.
abstract final class AppConfig {
  static const repoOwner = 'tsshack';
  static const repoName = 'tabriz-metro';

  static const repoUrl = 'https://github.com/$repoOwner/$repoName';
  static const issuesNewUrl = '$repoUrl/issues/new';
  static const releasesUrl = '$repoUrl/releases';
  static const releasesApi =
      'https://api.github.com/repos/$repoOwner/$repoName/releases';

  static const developerHandle = '@TssHack';
  static const developerWebsite = 'https://ehsanfazli.ir';
  static const developerGithub = 'https://github.com/tsshack';

  /// User agent for OSM tiles and the GitHub API.
  static const userAgentPackage = 'ir.ehsanfazli.tabriz_metro';

  /// CARTO basemaps (OpenStreetMap data); `{r}` becomes `@2x` on retina.
  static const cartoLightTileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const cartoDarkTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  /// Fallback when CARTO tiles fail to load.
  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
