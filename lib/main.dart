import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'core/utils/font_licenses.dart';
import 'data/repositories/asset_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final (prefs, data) = await (
    SharedPreferences.getInstance(),
    loadAppData(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDataProvider.overrideWithValue(data),
      ],
      child: const TabrizMetroApp(),
    ),
  );
}
