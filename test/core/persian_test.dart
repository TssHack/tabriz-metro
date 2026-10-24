import 'package:flutter_test/flutter_test.dart';
import 'package:tabriz_metro/core/utils/persian.dart';
import 'package:tabriz_metro/core/utils/time_format.dart';

void main() {
  group('digits', () {
    test('Latin → Persian', () {
      expect(toPersianDigits('12:05'), '۱۲:۰۵');
      expect(toPersianDigits('abc 0123456789'), 'abc ۰۱۲۳۴۵۶۷۸۹');
    });

    test('Persian and Arabic → Latin', () {
      expect(toLatinDigits('۱۲:۰۵'), '12:05');
      expect(toLatinDigits('٣٤'), '34');
    });

    test('localizeDigits', () {
      expect(localizeDigits('7', persian: true), '۷');
      expect(localizeDigits('۷', persian: false), '7');
    });
  });

  group('search normalization', () {
    test('Arabic Yeh/Kaf match Persian', () {
      expect(normalizeForSearch('كيان'), normalizeForSearch('کیان'));
      expect(searchMatches('امام رضا (ع)', 'امام رضا'), isTrue);
      expect(searchMatches('خیام', 'خيام'), isTrue);
    });

    test('ZWNJ and spaces are ignored', () {
      expect(searchMatches('میدان‌ساعت', 'میدان ساعت'), isTrue);
      expect(searchMatches('میدان ساعت', 'میدانساعت'), isTrue);
    });

    test('digits match in any script', () {
      expect(searchMatches('۲۹ بهمن', '29'), isTrue);
      expect(searchMatches('29 Bahman', '۲۹'), isTrue);
    });

    test('Latin is case-insensitive; empty query matches all', () {
      expect(searchMatches('Ostad Shahriar', 'shahr'), isTrue);
      expect(searchMatches('Noor', ''), isTrue);
      expect(searchMatches('Noor', 'xyz'), isFalse);
    });

    test('Hamza forms normalize', () {
      expect(searchMatches('ائل گؤلی', 'ایل گولی'), isTrue);
    });
  });

  group('time format', () {
    test('parse and format HH:MM', () {
      expect(parseHhMm('05:55'), 355);
      expect(parseHhMm('۲۱:۱۵'), 21 * 60 + 15);
      expect(formatMinutes(355), '05:55');
      expect(formatMinutes(355, persian: true), '۰۵:۵۵');
      expect(formatMinutes(24 * 60 + 5), '00:05');
      expect(() => parseHhMm('5'), throwsFormatException);
      expect(() => parseHhMm('25:99'), throwsFormatException);
    });

    test('Gregorian → Jalali', () {
      expect(
        JalaliDate.fromGregorian(DateTime(2025, 3, 21)).toString(),
        '1404/01/01',
      );
      expect(
        JalaliDate.fromGregorian(DateTime(2026, 10, 24)).toString(),
        '1405/08/02',
      );
      expect(
        JalaliDate.fromGregorian(DateTime(2027, 3, 20)).toString(),
        '1405/12/29',
      );
      expect(
        JalaliDate.fromGregorian(DateTime(2025, 9, 22)).monthNameFa,
        'شهریور',
      );
    });
  });
}
