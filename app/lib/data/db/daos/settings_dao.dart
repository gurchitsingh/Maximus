import 'dart:math';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../../../core/theme/theme_controller.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin
    implements SettingsWriter {
  SettingsDao(super.db);

  /// Inserts every missing default, and an install id if there is none.
  /// Existing values are kept.
  Future<void> seedDefaults() async {
    await batch((b) {
      b.insertAll(settings, [
        for (final e in SettingKeys.defaults.entries)
          SettingsCompanion.insert(key: e.key, value: e.value),
        SettingsCompanion.insert(
          key: SettingKeys.installId,
          value: newInstallId(),
        ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Future<Map<String, String>> readAll() async {
    final rows = await select(settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Stream<Map<String, String>> watchAll() =>
      select(settings)
          .watch()
          .map((rows) => {for (final r in rows) r.key: r.value});

  Future<String?> read(String key) async => (await (select(
    settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> write(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

/// UUID v4 from `Random.secure` (CONTRACTS 11), lowercase.
String newInstallId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
