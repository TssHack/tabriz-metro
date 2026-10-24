import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabriz_metro/app/app.dart';
import 'package:tabriz_metro/app/providers.dart';
import 'package:tabriz_metro/app/router.dart';
import 'package:tabriz_metro/app/settings.dart';
import 'package:tabriz_metro/data/repositories/update_repository.dart';
import 'package:tabriz_metro/features/update/update_controller.dart';

import '../helpers.dart';

/// Renders every screen at a narrow phone width in both languages and both
/// themes; any overflow or exception fails the test.
void main() {
  const routes = [
    Routes.home,
    Routes.map,
    Routes.timetable,
    Routes.stations,
    Routes.trip,
    Routes.automations,
    Routes.settings,
    Routes.location,
    Routes.update,
    Routes.about,
  ];

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Tabriz Metro',
      packageName: 'ir.ehsanfazli.tabriz_metro',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final lang in ['fa', 'en']) {
    for (final theme in ['light', 'dark']) {
      testWidgets('all screens render at 360px ($lang, $theme)', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'settings.v1':
              '{"languageCode":"$lang","persianDigits":${lang == 'fa'},'
              '"themeMode":"$theme","favorites":["noor","meydan-saat"]}',
        });
        final sp = await SharedPreferences.getInstance();
        await tester.binding.setSurfaceSize(const Size(360, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sp),
              appDataProvider.overrideWithValue(
                AppData(timetable: loadTimetable(), holidays: loadHolidays()),
              ),
              nowProvider.overrideWithValue(DateTime(2026, 10, 24, 7, 1)),
              updateRepositoryProvider.overrideWithValue(
                UpdateRepository(
                  client: MockClient((_) async => http.Response('[]', 200)),
                ),
              ),
            ],
            child: const TabrizMetroApp(runStartupTasks: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TabrizMetroApp)),
        );
        for (final r in routes) {
          container.read(routerProvider).go(r);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          final e = tester.takeException();
          expect(
            e,
            isNull,
            reason: '$r ($lang/$theme): '
                '${e is FlutterError ? e.toStringDeep() : e}',
          );
        }
        // City map mode.
        container.read(routerProvider).go(Routes.map);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(lang == 'fa' ? 'شهر' : 'City'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        final e = tester.takeException();
        expect(e, isNull, reason: 'city map: $e');

        // Leave the tree so pending timers (tiles, animations) are disposed.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
