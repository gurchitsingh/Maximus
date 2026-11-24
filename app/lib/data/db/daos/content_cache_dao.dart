import 'package:drift/drift.dart';

import '../app_database.dart';

part 'content_cache_dao.g.dart';

/// The content cache (CONTRACTS 5.1). An ETag describes one payload: a put
/// with no ETag keeps the stored one only when the payload is unchanged
/// (the API source stores the ETag, then the repository stores the same
/// body again), and drops it when the payload differs.
@DriftAccessor(tables: [CachedDocs, CachedTitles])
class ContentCacheDao extends DatabaseAccessor<AppDatabase>
    with _$ContentCacheDaoMixin {
  ContentCacheDao(super.db);

  Future<CachedTitleRow?> title(String titleId) => (select(
    cachedTitles,
  )..where((t) => t.titleId.equals(titleId))).getSingleOrNull();

  Future<void> putTitle({
    required String titleId,
    required String payload,
    required int contentVersion,
    String? etag,
  }) => transaction(() async {
    final old = etag == null ? await title(titleId) : null;
    await into(cachedTitles).insertOnConflictUpdate(
      CachedTitlesCompanion.insert(
        titleId: titleId,
        payload: payload,
        contentVersion: contentVersion,
        etag: Value(etag ?? (old?.payload == payload ? old?.etag : null)),
        fetchedAt: db.clock(),
      ),
    );
  });

  Future<CachedDocRow?> doc(String key) =>
      (select(cachedDocs)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<void> putDoc(String key, String payload, {String? etag}) =>
      transaction(() async {
        final old = etag == null ? await doc(key) : null;
        await into(cachedDocs).insertOnConflictUpdate(
          CachedDocsCompanion.insert(
            key: key,
            payload: payload,
            etag: Value(etag ?? (old?.payload == payload ? old?.etag : null)),
            fetchedAt: db.clock(),
          ),
        );
      });
}
