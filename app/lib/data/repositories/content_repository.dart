// Catalogue and title loading with the drift content cache (CONTRACTS 3.6).
import 'dart:convert';

import '../db/app_database.dart';
import '../models/catalogue.dart';
import '../models/title.dart';
import 'content_source.dart';

class ContentRepository {
  ContentRepository(this.db, this.source);

  final AppDatabase db;
  final ContentSource source;

  /// Fresh catalogue from the source, stored in `cached_docs['catalogue']`;
  /// the cached copy when the source fails.
  Future<Catalogue> catalogue() async {
    try {
      final body = await source.catalogueJson();
      final parsed = Catalogue.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      await db.contentCacheDao.putDoc('catalogue', body);
      return parsed;
    } catch (_) {
      final cached = await db.contentCacheDao.doc('catalogue');
      if (cached == null) rethrow;
      return Catalogue.fromJson(
        jsonDecode(cached.payload) as Map<String, dynamic>,
      );
    }
  }

  /// "Open a title" (3.6): a cached copy at least as new as the catalogue's
  /// `content_version` is used as is; otherwise fetch, cache whole, return.
  /// A failed fetch falls back to an older cached copy.
  Future<TitleDetail> title(String id, {int? catalogueVersion}) async {
    final cached = await db.contentCacheDao.title(id);
    if (cached != null &&
        (catalogueVersion == null ||
            cached.contentVersion >= catalogueVersion)) {
      return _parse(cached.payload);
    }
    try {
      final body = await source.titleJson(id);
      final detail = _parse(body);
      await db.contentCacheDao.putTitle(
        titleId: id,
        payload: body,
        contentVersion: detail.summary.contentVersion,
      );
      return detail;
    } catch (_) {
      if (cached != null) return _parse(cached.payload);
      rethrow;
    }
  }

  /// "Stale titles" (3.6): refetch, in the background and at most
  /// [parallel] at once, every cached title in [ids] whose catalogue
  /// `content_version` is higher than the cached one. Uncached titles wait
  /// until they are opened. Returns how many were refreshed.
  Future<int> refreshStale(
    Catalogue catalogue,
    Iterable<String> ids, {
    int parallel = 3,
  }) async {
    final queue = <({String id, int version})>[];
    for (final id in ids.toSet()) {
      final summary = catalogue.title(id);
      final cached = await db.contentCacheDao.title(id);
      if (summary != null &&
          cached != null &&
          cached.contentVersion < summary.contentVersion) {
        queue.add((id: id, version: summary.contentVersion));
      }
    }
    var refreshed = 0;
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final next = queue.removeAt(0);
        try {
          final t = await title(next.id, catalogueVersion: next.version);
          if (t.summary.contentVersion >= next.version) refreshed++;
        } catch (_) {
          // Offline: the cached copy keeps working.
        }
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    return refreshed;
  }

  TitleDetail _parse(String body) =>
      TitleDetail.fromJson(jsonDecode(body) as Map<String, dynamic>);
}
