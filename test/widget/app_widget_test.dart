import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabriz_metro/app/app.dart';
import 'package:tabriz_metro/app/providers.dart';
import 'package:tabriz_metro/app/settings.dart';
import 'package:tabriz_metro/features/timetable/timetable_screen.dart';

import '../helpers.dart';

// Saturday 2026-10-24 07:01 (weekday timetable).
final _now = DateTime(2026, 10, 24, 7, 1);

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final data = AppData(timetable: loadTimetable(), holidays: loadHolidays());
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        appDataProvider.overrideWithValue(data),
        nowProvider.overrideWithValue(_now),
      ],
      child: const TabrizMetroApp(runStartupTasks: false),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Home renders RTL with Persian next departures', (tester) async {
    await _pumpApp(tester);

    final dir = Directionality.of(
      tester.element(find.text('مترو تبریز').first),
    );
    expect(dir, TextDirection.rtl);

    expect(find.text('ایستگاه شما'), findsOneWidget);
    expect(find.text('ائل گؤلی'), findsWidgets); // default station
    expect(find.text('قطارهای بعدی'), findsOneWidget);
    expect(find.text('روز عادی'), findsOneWidget);
    expect(find.text('هر ۱۵ دقیقه'), findsOneWidget);
    // Next train from Eyl Goli toward Noor is 07:10 → 9 minutes.
    expect(find.text('به سمت نور'), findsOneWidget);
    expect(find.text('۹'), findsOneWidget);
    expect(find.text('حرکت ۰۷:۱۰'), findsOneWidget);
    // Eyl Goli is the end of the line toward Eyl Goli.
    expect(find.text('انتهای خط در این جهت'), findsOneWidget);
    // Bottom navigation labels.
    for (final label in ['خانه', 'نقشه خط', 'زمان‌بندی', 'ایستگاه‌ها']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Home honours Latin digits and the selected station', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      prefs: {
        'settings.v1': '{"persianDigits":false,"selectedStationId":"meydan-saat","favorites":["noor"]}',
      },
    );
    expect(find.text('میدان ساعت'), findsOneWidget);
    expect(find.text('هر 15 دقیقه'), findsOneWidget);
    // Favorite chip.
    expect(find.text('نور'), findsWidgets);
    expect(find.text('به سمت ائل گؤلی'), findsOneWidget);
  });

  testWidgets('Timetable shows hours, banner and highlights the next train', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('زمان‌بندی').last);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TimetableScreen), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(TimetableScreen)));
    expect(dir, TextDirection.rtl);
    expect(find.text('ساعت ۰۵'), findsOneWidget);
    expect(find.textContaining('اولین قطار: ۰۵:۵۵'), findsOneWidget);
    expect(find.textContaining('آخرین قطار: ۲۰:۴۰'), findsOneWidget);
    // Past, next and future chips all render.
    expect(find.text('۰۵:۵۵'), findsOneWidget);
    expect(find.text('۰۷:۱۰'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('۲۰:۴۰'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ساعت ۲۰'), findsOneWidget);

    // Switching to the holiday timetable changes the first train.
    await tester.scrollUntilVisible(
      find.text('جمعه و تعطیل'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('جمعه و تعطیل'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('اولین قطار: ۰۷:۳۰'), findsOneWidget);
  });

  testWidgets('English locale renders LTR', (tester) async {
    await _pumpApp(
      tester,
      prefs: {'settings.v1': '{"languageCode":"en","persianDigits":false}'},
    );
    final dir = Directionality.of(
      tester.element(find.text('Tabriz Metro').first),
    );
    expect(dir, TextDirection.ltr);
    expect(find.text('Next trains'), findsOneWidget);
    expect(find.text('Toward Noor'), findsOneWidget);
  });
}
