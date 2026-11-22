import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/theme/font_licenses.dart';

void main() {
  registerFontLicenses();
  // The drift database opens here from S6 (CONTRACTS 8.1).
  runApp(const ProviderScope(child: MaximusApp()));
}
