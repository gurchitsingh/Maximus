import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/theme/font_licenses.dart';
import 'core/theme/theme_controller.dart';
import 'data/api/api_client.dart' show apiBaseUrl, requireHttpsInRelease;
import 'data/db/app_database.dart';
import 'data/providers.dart';
import 'data/repositories/credits_repository.dart';
import 'features/feed/feed_providers.dart';
import 'features/on_this_day/on_this_day_card.dart';
import 'features/settings/account_section.dart' show appBaseUrl;

/// `--dart-define=DEV_CONTENT=true` runs on the bundled assets/dev samples
/// with no backend (UI work); otherwise content comes from /v1 (S12).
const _devContent = bool.fromEnvironment('DEV_CONTENT');

Future<void> main() async {
  // A release build must never talk cleartext HTTP; stop before anything runs.
  requireHttpsInRelease('API_BASE_URL', apiBaseUrl, isRelease: kReleaseMode);
  requireHttpsInRelease('APP_BASE_URL', appBaseUrl, isRelease: kReleaseMode);
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
        if (!_devContent) ...[
          contentSourceProvider.overrideWith(
            (ref) => ref.watch(apiContentSourceProvider),
          ),
          feedSourceProvider.overrideWith(
            (ref) => ref.watch(apiContentSourceProvider),
          ),
          onThisDaySourceProvider.overrideWith(
            (ref) => ref.watch(apiContentSourceProvider),
          ),
          creditsSourceProvider.overrideWith(
            (ref) => ref.watch(apiContentSourceProvider),
          ),
        ],
      ],
      child: const MaximusApp(),
    ),
  );
}
