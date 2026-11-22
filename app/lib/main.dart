import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/theme/font_licenses.dart';
import 'core/theme/theme_controller.dart';
import 'data/db/app_database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Open drift and read the stored theme and text size before the first
  // frame, so the app never flashes the default theme (CONTRACTS 8.1).
  final db = AppDatabase.open();
  final stored = await db.settingsDao.readAll();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialThemeSettingsProvider.overrideWithValue(
          ThemeSettings.fromStored(stored),
        ),
        settingsWriterProvider.overrideWithValue(db.settingsDao),
      ],
      child: const MaximusApp(),
    ),
  );
}
