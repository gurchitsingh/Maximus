// The real content source (S12): /v1 behind the interfaces the dev assets
// implemented, so repositories and screens did not change (CONTRACTS 3.6).
//
// HTTP cache: every ETag endpoint sends the stored ETag as If-None-Match; a
// 304 returns the stored payload. A 200 is checked to be a JSON object, then
// stored with its ETag before it is returned. Offline and server errors
// surface as ApiException, and the repositories fall back to the cache.
import 'dart:convert';

import '../db/daos/content_cache_dao.dart';
import '../repositories/content_source.dart';
import '../repositories/credits_repository.dart';
import '../repositories/feed_repository.dart';
import '../repositories/on_this_day_repository.dart';
import 'api_client.dart';
import 'api_error.dart';

final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

class ApiContentSource
    implements ContentSource, FeedSource, OnThisDaySource, CreditsSource {
  ApiContentSource(this.client, this.cache, {this.prefetchImages});

  final ApiClient client;
  final ContentCacheDao cache;

  /// Called with a freshly fetched title's image URLs ("then prefetch all
  /// its images", 3.6). Fire and forget.
  final void Function(List<String> urls)? prefetchImages;

  @override
  Future<String> catalogueJson() => _doc('catalogue', '/v1/catalogue');

  @override
  Future<String> creditsJson() => _doc('credits', '/v1/credits');

  @override
  Future<String> onThisDayJson(String mmdd) =>
      _doc('otd:$mmdd', '/v1/on-this-day', query: {'date': mmdd});

  /// `Cache-Control: no-store`: never cached, never conditional.
  @override
  Future<String> feedJson(List<String> titleIds, {int limit = 10}) async {
    final ids = titleIds.where(_slug.hasMatch).toSet().take(30).toList();
    if (ids.isEmpty) return '{"facts":[],"images":[]}';
    final r = await client.get(
      '/v1/feed',
      query: {'title_ids': ids.join(','), 'limit': '${limit.clamp(1, 50)}'},
    );
    return _object((r as ApiBody).body);
  }

  @override
  Future<String> titleJson(String id) async {
    // Only slugs: an id never builds an arbitrary path.
    if (!_slug.hasMatch(id)) throw TitleNotFound(id);
    final cached = await cache.title(id);
    final ApiResult r;
    try {
      r = await client.get('/v1/titles/$id', etag: cached?.etag);
    } on ApiException catch (e) {
      if (e.code == 'title_not_found' || e.status == 404) {
        throw TitleNotFound(id);
      }
      rethrow;
    }
    switch (r) {
      case ApiNotModified():
        return cached!.payload;
      case ApiBody(:final body, :final etag):
        final json = jsonDecode(_object(body)) as Map<String, dynamic>;
        await cache.putTitle(
          titleId: id,
          payload: body,
          contentVersion: json['content_version'] as int,
          etag: etag,
        );
        prefetchImages?.call([
          for (final i in json['images'] as List? ?? const <Object?>[])
            if (i is Map && i['url'] is String) i['url'] as String,
        ]);
        return body;
    }
  }

  Future<String> _doc(
    String key,
    String path, {
    Map<String, String>? query,
  }) async {
    final cached = await cache.doc(key);
    final r = await client.get(path, query: query, etag: cached?.etag);
    switch (r) {
      case ApiNotModified():
        return cached!.payload;
      case ApiBody(:final body, :final etag):
        await cache.putDoc(key, _object(body), etag: etag);
        return body;
    }
  }

  /// A 200 that is not a JSON object (a captive portal page) must never
  /// replace a good cached copy.
  static String _object(String body) {
    try {
      if (jsonDecode(body) is Map<String, dynamic>) return body;
    } on FormatException {
      // Falls through.
    }
    throw const ApiException(
      code: ApiException.badResponse,
      status: 200,
      message: 'body is not a JSON object',
    );
  }
}
