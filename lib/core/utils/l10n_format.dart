import '../../l10n/generated/app_localizations.dart';
import 'format.dart';

/// "450 m" / "1.2 km" in the user's language and digits.
String formatDistance(AppLocalizations l, Fmt fmt, double meters) {
  final d = fmt.distance(meters);
  return d.km ? l.distanceKm(d.value) : l.distanceMeters(d.value);
}
