// Registers the bundled OFL texts with Flutter's licence page (DESIGN_SPEC 2.1).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _fonts = {
  'Figtree': 'assets/fonts/Figtree/OFL.txt',
  'Cinzel': 'assets/fonts/Cinzel/OFL.txt',
  'Caveat Brush': 'assets/fonts/CaveatBrush/OFL.txt',
  'Big Shoulders Stencil Display': 'assets/fonts/BigShouldersStencil/OFL.txt',
};

void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in _fonts.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
