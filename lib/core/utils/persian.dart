/// Persian text helpers: digit conversion and search normalization.
///
/// Pure Dart — no Flutter imports.
library;

const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts ASCII digits in [input] to Persian (Extended Arabic-Indic) digits.
String toPersianDigits(String input) {
  final buf = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buf.write(_faDigits[unit - 0x30]);
    } else {
      buf.writeCharCode(unit);
    }
  }
  return buf.toString();
}

/// Converts Persian and Arabic-Indic digits in [input] to ASCII digits.
String toLatinDigits(String input) {
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(_faDigits[i], '$i').replaceAll(_arDigits[i], '$i');
  }
  return out;
}

/// Renders [input] with Persian digits when [persian] is true, otherwise
/// with Latin digits.
String localizeDigits(String input, {required bool persian}) =>
    persian ? toPersianDigits(input) : toLatinDigits(input);

/// Normalizes Persian/Arabic text for search matching:
/// - Arabic Yeh/Alef Maksura → Persian Yeh, Arabic Kaf → Persian Keheh
/// - Teh Marbuta → Heh, Alef variants → Alef
/// - removes ZWNJ, tatweel and diacritics; collapses whitespace
/// - converts digits to Latin and lowercases Latin letters
String normalizeForSearch(String input) {
  var s = toLatinDigits(input).toLowerCase();
  const map = {
    'ي': 'ی',
    'ى': 'ی',
    'ئ': 'ی',
    'ك': 'ک',
    'ة': 'ه',
    'ۀ': 'ه',
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ؤ': 'و',
  };
  map.forEach((k, v) => s = s.replaceAll(k, v));
  // ZWNJ (U+200C), ZWJ (U+200D), tatweel (U+0640) and Arabic diacritics.
  s = s.replaceAll(RegExp('[‌‍ـً-ٰٟ]'), '');
  s = s.replaceAll(RegExp(r'[\s\-_.,()]+'), ' ').trim();
  return s;
}

/// Returns true when [query] matches [candidate] after normalization.
/// Whitespace in either side is ignored so "میدانساعت" matches "میدان ساعت".
bool searchMatches(String candidate, String query) {
  final q = normalizeForSearch(query).replaceAll(' ', '');
  if (q.isEmpty) return true;
  return normalizeForSearch(candidate).replaceAll(' ', '').contains(q);
}
