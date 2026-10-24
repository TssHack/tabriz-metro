import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled font and data licenses to the license page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/vazirmatn/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Vazirmatn'], ofl);
    yield const LicenseEntryWithLineBreaks(
      ['OpenStreetMap data'],
      'Station coordinates and map tiles © OpenStreetMap contributors, '
      'available under the Open Database License (ODbL) 1.0.',
    );
  });
}
