import 'persian.dart';
import 'time_format.dart';

/// Formatting bound to the user's digit preference.
class Fmt {
  const Fmt({required this.persianDigits});

  final bool persianDigits;

  String digits(Object value) =>
      localizeDigits('$value', persian: persianDigits);

  String clock(DateTime t) => formatClock(t, persian: persianDigits);

  String minutes(int minutesOfDay) =>
      formatMinutes(minutesOfDay, persian: persianDigits);

  /// Distance: meters below 1 km, else km with one decimal.
  ({String value, bool km}) distance(double meters) {
    if (meters < 1000) {
      final rounded = (meters / 10).round() * 10;
      return (value: digits(rounded), km: false);
    }
    return (value: digits((meters / 1000).toStringAsFixed(1)), km: true);
  }

  String bytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return digits('${(bytes / 1024).toStringAsFixed(0)} KB');
    }
    return digits('${(bytes / 1024 / 1024).toStringAsFixed(1)} MB');
  }
}
