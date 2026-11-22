import 'package:drift/drift.dart';

import '../app_database.dart';

part 'content_cache_dao.g.dart';

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
  }) => into(cachedTitles).insertOnConflictUpdate(
    CachedTitlesCompanion.insert(
      titleId: titleId,
      payload: payload,
      contentVersion: contentVersion,
      etag: Value(etag),
      fetchedAt: db.clock(),
    ),
  );

  Future<CachedDocRow?> doc(String key) =>
      (select(cachedDocs)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<void> putDoc(String key, String payload, {String? etag}) =>
      into(cachedDocs).insertOnConflictUpdate(
        CachedDocsCompanion.insert(
          key: key,
          payload: payload,
          etag: Value(etag),
          fetchedAt: db.clock(),
        ),
      );
}
