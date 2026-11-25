import 'dart:math';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../../../core/theme/theme_controller.dart';
import '../../sync/sync_record.dart' show utcMs;

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin
    implements SettingsWriter {
  SettingsDao(super.db);

  /// Inserts every missing default, and an install id if there is none.
  /// Existing values are kept. Seeded rows are clean with `updated_at` =
  /// the epoch, so a value the account already has always wins (15.5).
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

  /// "Clear my data" (15.5): every synced key back to its default as a
  /// change (dirty, stamped now) so other devices reset too, and a new
  /// install id (never synced).
  Future<void> resetToDefaults() => transaction(() async {
    for (final e in SettingKeys.defaults.entries) {
      await _put(e.key, e.value, force: true);
    }
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: SettingKeys.installId,
        value: newInstallId(),
        dirty: const Value(false),
      ),
    );
  });

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

  /// A local change: stamped now (never earlier than the stored stamp, so
  /// a clock that went back cannot lose the user's latest choice) and
  /// dirty, except install_id, which never syncs.
  @override
  Future<void> write(String key, String value) => _put(key, value);

  Future<void> _put(String key, String value, {bool force = false}) =>
      transaction(() async {
    final old = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (!force && old != null && old.value == value && !old.deleted) {
      return;
    }
    final synced = SettingKeys.synced.contains(key);
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: Value(stampAfter(db.clock(), old?.updatedAt)),
        deleted: const Value(false),
        dirty: Value(synced),
      ),
    );
  });
}

/// `now` in UTC milliseconds, but at least 1 ms after [previous].
DateTime stampAfter(DateTime now, DateTime? previous) {
  final t = utcMs(now);
  if (previous == null || t.isAfter(previous)) return t;
  return utcMs(previous).add(const Duration(milliseconds: 1));
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
