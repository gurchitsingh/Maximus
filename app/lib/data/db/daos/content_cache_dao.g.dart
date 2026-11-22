// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedDocsTable get cachedDocs => attachedDatabase.cachedDocs;
  $CachedTitlesTable get cachedTitles => attachedDatabase.cachedTitles;
  ContentCacheDaoManager get managers => ContentCacheDaoManager(this);
}

class ContentCacheDaoManager {
  final _$ContentCacheDaoMixin _db;
  ContentCacheDaoManager(this._db);
  $$CachedDocsTableTableManager get cachedDocs =>
      $$CachedDocsTableTableManager(_db.attachedDatabase, _db.cachedDocs);
  $$CachedTitlesTableTableManager get cachedTitles =>
      $$CachedTitlesTableTableManager(_db.attachedDatabase, _db.cachedTitles);
}
