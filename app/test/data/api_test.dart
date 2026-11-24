// S12: the /v1 client, the drift HTTP cache (ETag, If-None-Match, 304) and
// the offline paths (CONTRACTS 3, 3.5, 3.6). A fake dio adapter plays the
// server; nothing touches the network.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/api/api_client.dart';
import 'package:maximus/data/api/api_content_source.dart';
import 'package:maximus/data/api/api_error.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/models/catalogue.dart';
import 'package:maximus/data/repositories/content_repository.dart';
import 'package:maximus/data/repositories/content_source.dart';
import 'package:maximus/data/repositories/credits_repository.dart';
import 'package:maximus/data/repositories/feed_repository.dart';
import 'package:maximus/data/repositories/on_this_day_repository.dart';

String readFile(String path) => File(path).readAsStringSync();

/// One canned reply.
class Reply {
  const Reply(this.status, [this.body = '', this.headers = const {}]);
  final int status;
  final String body;
  final Map<String, String> headers;
}

/// The fake server. [routes] maps a path to a reply builder; [offline]
/// makes every request fail like a dead connection.
class FakeServer implements HttpClientAdapter {
  final routes = <String, Reply Function(RequestOptions)>{};
  final requests = <RequestOptions>[];
  bool offline = false;
  int inFlight = 0, maxInFlight = 0;
  Duration delay = Duration.zero;

  /// Serves [body] with ETag [etag] and answers 304 to a matching
  /// If-None-Match, like backend/app/services/etag.py.
  void serve(String path, String body, String etag) {
    routes[path] = (o) => o.headers['If-None-Match'] == etag
        ? Reply(304, '', {'etag': etag})
        : Reply(200, body, {'etag': etag});
  }

  int hits(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('Network is unreachable'),
      );
    }
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final route = routes[options.path];
      final reply = route == null
          ? const Reply(
              404,
              '{"error":{"code":"not_found","message":"No such endpoint.",'
              '"retry_after_s":null,"details":null}}',
            )
          : route(options);
      return ResponseBody.fromString(
        reply.body,
        reply.status,
        headers: {
          'content-type': ['application/json; charset=utf-8'],
          for (final e in reply.headers.entries) e.key: [e.value],
        },
      );
    } finally {
      inFlight--;
    }
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> withVersion(String path, int v) =>
    (jsonDecode(readFile(path)) as Map<String, dynamic>)
      ..['content_version'] = v;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final catalogueBody = readFile('../docs/examples/catalogue.json');
  final romanBody = readFile('../backend/data/samples/roman-history.json');
  final errors = [
    for (final e
        in jsonDecode(readFile('../docs/examples/errors.json')) as List)
      e as Map<String, dynamic>,
  ];
  Map<String, dynamic> errorExample(String code) =>
      errors.firstWhere((e) => (e['error'] as Map)['code'] == code);

  late FakeServer server;
  late ApiClient client;
  late AppDatabase db;
  late List<List<String>> prefetched;
  late ApiContentSource source;
  late ContentRepository repo;

  setUp(() {
    server = FakeServer();
    client = ApiClient(dio: Dio()..httpClientAdapter = server);
    db = AppDatabase(NativeDatabase.memory());
    prefetched = [];
    source = ApiContentSource(
      client,
      db.contentCacheDao,
      prefetchImages: prefetched.add,
    );
    repo = ContentRepository(db, source);
  });
  tearDown(() => db.close());

  group('ApiClient', () {
    test('default base URL is the emulator host', () {
      expect(apiBaseUrl, 'http://10.0.2.2:8000');
      expect(ApiClient().baseUrl, 'http://10.0.2.2:8000');
    });

    test('200 returns the raw body and the ETag, asks for JSON', () async {
      server.serve('/v1/catalogue', catalogueBody, '"abc"');
      final r = await client.get('/v1/catalogue') as ApiBody;
      expect(r.body, catalogueBody);
      expect(r.etag, '"abc"');
      final sent = server.requests.single;
      expect(sent.headers['Accept'], 'application/json');
      expect(sent.headers.containsKey('If-None-Match'), isFalse);
    });

    test('sends If-None-Match and maps 304 to ApiNotModified', () async {
      server.serve('/v1/catalogue', catalogueBody, '"abc"');
      expect(
        await client.get('/v1/catalogue', etag: '"abc"'),
        isA<ApiNotModified>(),
      );
      expect(server.requests.single.headers['If-None-Match'], '"abc"');
      expect(await client.get('/v1/catalogue', etag: '"old"'), isA<ApiBody>());
    });

    test('a 304 to an unconditional request is a bad response', () async {
      server.routes['/x'] = (_) => const Reply(304);
      await expectLater(
        client.get('/x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiException.badResponse,
          ),
        ),
      );
    });

    // Every docs/examples/errors.json body maps to its code, retry and
    // details (CONTRACTS 3.5).
    for (final (code, status) in [
      ('bad_request', 400),
      ('validation_error', 422),
      ('not_found', 404),
      ('title_not_found', 404),
      ('rate_limited', 429),
      ('chat_daily_cap', 429),
      ('chat_resting', 503),
      ('upstream_unavailable', 503),
      ('internal_error', 500),
    ]) {
      test('error body $code ($status)', () async {
        final example = errorExample(code);
        final err = example['error'] as Map<String, dynamic>;
        server.routes['/e'] = (_) => Reply(status, jsonEncode(example), {
          if (err['retry_after_s'] != null)
            'retry-after': '${err['retry_after_s']}',
        });
        try {
          await client.get('/e');
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.code, code);
          expect(e.status, status);
          expect(e.message, err['message']);
          expect(e.retryAfterS, err['retry_after_s']);
          expect(e.details, err['details']);
          expect(e.isOffline, isFalse);
        }
      });
    }

    test('a non-contract error body falls back to the status code', () async {
      server.routes['/e'] = (_) =>
          const Reply(502, '<html>Bad gateway</html>', {'retry-after': '7'});
      try {
        await client.get('/e');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'internal_error');
        expect(e.status, 502);
        expect(e.retryAfterS, 7);
      }
    });

    test('no connection is offline', () async {
      server.offline = true;
      try {
        await client.get('/v1/catalogue');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.code, ApiException.offline);
        expect(e.status, isNull);
        expect(isOfflineError(e), isTrue);
      }
      expect(isOfflineError(Exception('x')), isFalse);
    });
  });

  group('ETag cache (drift)', () {
    test(
      'catalogue: 200 cached with its ETag, then 304 uses the cache',
      () async {
        server.serve('/v1/catalogue', catalogueBody, '"c1"');
        final first = await repo.catalogue();
        final row = await db.contentCacheDao.doc('catalogue');
        expect(row!.payload, catalogueBody);
        // The repository stores the same body again: the ETag survives.
        expect(row.etag, '"c1"');

        final second = await repo.catalogue();
        expect(server.requests.last.headers['If-None-Match'], '"c1"');
        expect(second.catalogueVersion, first.catalogueVersion);
        expect((await db.contentCacheDao.doc('catalogue'))!.etag, '"c1"');
      },
    );

    test('a changed payload replaces body and ETag', () async {
      server.serve('/v1/catalogue', catalogueBody, '"c1"');
      await repo.catalogue();
      final changed = (jsonDecode(catalogueBody) as Map<String, dynamic>)
        ..['catalogue_version'] = 'ffffffffffffffff';
      server.serve('/v1/catalogue', jsonEncode(changed), '"c2"');
      final c = await repo.catalogue();
      expect(c.catalogueVersion, 'ffffffffffffffff');
      expect((await db.contentCacheDao.doc('catalogue'))!.etag, '"c2"');
    });

    test(
      'DAO: a put without ETag keeps it only for the same payload',
      () async {
        final dao = db.contentCacheDao;
        await dao.putDoc('k', '{"a":1}', etag: '"e"');
        await dao.putDoc('k', '{"a":1}');
        expect((await dao.doc('k'))!.etag, '"e"');
        await dao.putDoc('k', '{"a":2}');
        expect((await dao.doc('k'))!.etag, isNull);

        await dao.putTitle(
          titleId: 't',
          payload: 'p',
          contentVersion: 1,
          etag: '"t"',
        );
        await dao.putTitle(titleId: 't', payload: 'p', contentVersion: 1);
        expect((await dao.title('t'))!.etag, '"t"');
        await dao.putTitle(titleId: 't', payload: 'q', contentVersion: 2);
        expect((await dao.title('t'))!.etag, isNull);
      },
    );

    test('title: cached with version and ETag, images prefetched', () async {
      server.serve('/v1/titles/roman-history', romanBody, '"r1"');
      final t = await repo.title('roman-history');
      final row = await db.contentCacheDao.title('roman-history');
      expect(row!.etag, '"r1"');
      expect(row.contentVersion, t.summary.contentVersion);
      expect(prefetched.single, [for (final i in t.images) i.url]);

      // Cached and current: no request at all.
      await repo.title(
        'roman-history',
        catalogueVersion: t.summary.contentVersion,
      );
      expect(server.hits('/v1/titles/roman-history'), 1);
    });

    test(
      'stale title: conditional refetch, 304 keeps the cached copy',
      () async {
        server.serve('/v1/titles/roman-history', romanBody, '"r1"');
        final t = await repo.title('roman-history');
        final v = t.summary.contentVersion;
        final again = await repo.title(
          'roman-history',
          catalogueVersion: v + 1,
        );
        expect(server.requests.last.headers['If-None-Match'], '"r1"');
        expect(again.summary.contentVersion, v);
        expect(prefetched, hasLength(1), reason: 'no prefetch on 304');
      },
    );

    test('stale title: a new version replaces the cache', () async {
      server.serve('/v1/titles/roman-history', romanBody, '"r1"');
      await repo.title('roman-history');
      final v2 = jsonEncode(
        withVersion('../backend/data/samples/roman-history.json', 9),
      );
      server.serve('/v1/titles/roman-history', v2, '"r9"');
      final t = await repo.title('roman-history', catalogueVersion: 9);
      expect(t.summary.contentVersion, 9);
      final row = await db.contentCacheDao.title('roman-history');
      expect((row!.contentVersion, row.etag), (9, '"r9"'));
    });

    test('404 is TitleNotFound; a bad id never builds a path', () async {
      server.routes['/v1/titles/napoleon-bonaparte'] = (_) =>
          Reply(404, jsonEncode(errorExample('title_not_found')));
      await expectLater(
        source.titleJson('napoleon-bonaparte'),
        throwsA(isA<TitleNotFound>()),
      );
      await expectLater(
        source.titleJson('../v1/catalogue'),
        throwsA(isA<TitleNotFound>()),
      );
      expect(server.requests, hasLength(1));
    });

    test('a 200 that is not JSON never replaces a good copy', () async {
      server.serve('/v1/catalogue', catalogueBody, '"c1"');
      await repo.catalogue();
      server.routes['/v1/catalogue'] = (_) =>
          const Reply(200, '<html>Sign in to the Wi-Fi</html>');
      final c = await repo.catalogue();
      expect(c.titles, isNotEmpty);
      final row = await db.contentCacheDao.doc('catalogue');
      expect((row!.payload, row.etag), (catalogueBody, '"c1"'));
    });
  });

  group('offline', () {
    test('cached catalogue and title work with no network', () async {
      server
        ..serve('/v1/catalogue', catalogueBody, '"c1"')
        ..serve('/v1/titles/roman-history', romanBody, '"r1"');
      final c = await repo.catalogue();
      final v = c.title('roman-history')!.contentVersion;
      await repo.title('roman-history', catalogueVersion: v);

      server.offline = true;
      expect((await repo.catalogue()).titles, hasLength(c.titles.length));
      final t = await repo.title('roman-history', catalogueVersion: v);
      expect(t.lessons, isNotEmpty);
      // Even when the catalogue says the copy is stale.
      final stale = await repo.title('roman-history', catalogueVersion: v + 5);
      expect(stale.summary.contentVersion, v);
    });

    test(
      'first run offline: the catalogue error is an offline error',
      () async {
        server.offline = true;
        await expectLater(repo.catalogue(), throwsA(predicate(isOfflineError)));
      },
    );

    test('uncached title offline fails (needs a connection)', () async {
      server.offline = true;
      await expectLater(
        repo.title('chanakya'),
        throwsA(predicate(isOfflineError)),
      );
    });

    test('server error falls back to the cache too', () async {
      server.serve('/v1/catalogue', catalogueBody, '"c1"');
      await repo.catalogue();
      server.routes['/v1/catalogue'] = (_) =>
          Reply(500, jsonEncode(errorExample('internal_error')));
      expect((await repo.catalogue()).titles, isNotEmpty);
    });
  });

  group('empty catalogue', () {
    test('no titles parses and is cached', () async {
      final empty = (jsonDecode(catalogueBody) as Map<String, dynamic>)
        ..['featured_id'] = null
        ..['onboarding_leader_ids'] = <String>[]
        ..['titles'] = <Object>[]
        ..['images'] = <Object>[];
      server.serve('/v1/catalogue', jsonEncode(empty), '"e"');
      final c = await repo.catalogue();
      expect(c.titles, isEmpty);
      expect(c.groups, hasLength(12));
      expect(c.title(c.featuredId ?? ''), isNull);
    });
  });

  group('stale study-list refresh', () {
    test('refetches only cached, stale titles, pool-limited', () async {
      final ids = ['roman-history', 'shivaji-maharaj', 'chanakya'];
      for (final id in ids) {
        server.serve(
          '/v1/titles/$id',
          readFile('../backend/data/samples/$id.json'),
          '"$id-1"',
        );
        await repo.title(id);
      }
      // Two more stale cached titles, so the pool limit matters.
      for (final id in ['extra-one', 'extra-two']) {
        final j = withVersion('../backend/data/samples/chanakya.json', 1)
          ..['id'] = id;
        await db.contentCacheDao.putTitle(
          titleId: id,
          payload: jsonEncode(j),
          contentVersion: 1,
        );
      }
      final catalogueJson = jsonDecode(catalogueBody) as Map<String, dynamic>;
      final summaries = (catalogueJson['titles'] as List)
          .cast<Map<String, dynamic>>();
      for (final id in ['extra-one', 'extra-two']) {
        summaries.add({...summaries.last, 'id': id, 'content_version': 2});
      }
      // roman-history and the extras are stale; the others are current.
      summaries.firstWhere(
        (s) => s['id'] == 'roman-history',
      )['content_version'] = 9;
      final c = Catalogue.fromJson(catalogueJson);
      for (final id in ['roman-history', 'extra-one', 'extra-two']) {
        final base = id == 'roman-history' ? id : 'chanakya';
        server.serve(
          '/v1/titles/$id',
          jsonEncode(
            withVersion(
              '../backend/data/samples/$base.json',
              id == base ? 9 : 2,
            )..['id'] = id,
          ),
          '"$id-new"',
        );
      }
      server
        ..requests.clear()
        ..delay = const Duration(milliseconds: 20)
        ..maxInFlight = 0;

      final n = await repo.refreshStale(c, [
        ...ids,
        'extra-one',
        'extra-two',
        'not-cached',
      ], parallel: 2);
      expect(n, 3);
      expect(server.requests.map((r) => r.path).toSet(), {
        '/v1/titles/roman-history',
        '/v1/titles/extra-one',
        '/v1/titles/extra-two',
      });
      expect(server.maxInFlight, 2);
      expect(
        (await db.contentCacheDao.title('roman-history'))!.contentVersion,
        9,
      );
    });

    test('offline refresh keeps the cached copies', () async {
      server.serve('/v1/titles/roman-history', romanBody, '"r1"');
      final t = await repo.title('roman-history');
      server.offline = true;
      final catalogueJson = jsonDecode(catalogueBody) as Map<String, dynamic>;
      (catalogueJson['titles'] as List).cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id'] == 'roman-history',
      )['content_version'] = t.summary.contentVersion + 1;
      final n = await repo.refreshStale(Catalogue.fromJson(catalogueJson), [
        'roman-history',
      ]);
      expect(n, 0);
      expect(await db.contentCacheDao.title('roman-history'), isNotNull);
    });
  });

  group('feed, On This Day, credits over /v1', () {
    test('feed: query params, no ETag, nothing cached', () async {
      server.routes['/v1/feed'] = (_) =>
          Reply(200, readFile('../docs/examples/feed.json'));
      final c = Catalogue.fromJson(
        jsonDecode(catalogueBody) as Map<String, dynamic>,
      );
      final entries = await FeedRepository(
        repo,
        source,
      ).tryEntries(c, ['shivaji-maharaj', 'chanakya'], limit: 10);
      expect(entries, isNotEmpty);
      final sent = server.requests.single;
      expect(sent.queryParameters, {
        'title_ids': 'shivaji-maharaj,chanakya',
        'limit': '10',
      });
      expect(sent.headers.containsKey('If-None-Match'), isFalse);
      expect(await (db.select(db.cachedDocs)).get(), isEmpty);

      // No ids: no request.
      expect(jsonDecode(await source.feedJson(const [])), {
        'facts': <Object>[],
        'images': <Object>[],
      });
      expect(server.requests, hasLength(1));
    });

    test('feed offline: no try cards', () async {
      server.offline = true;
      final c = Catalogue.fromJson(
        jsonDecode(catalogueBody) as Map<String, dynamic>,
      );
      expect(
        await FeedRepository(repo, source).tryEntries(c, ['chanakya']),
        isEmpty,
      );
    });

    test(
      'On This Day: date param, otd:MM-DD cache, offline same day',
      () async {
        final now = DateTime.now();
        final mmdd = mmddOf(now);
        final body = (jsonDecode(
          readFile('../docs/examples/on-this-day.json'),
        ) as Map<String, dynamic>)..['date'] = mmdd;
        server.serve('/v1/on-this-day', jsonEncode(body), '"o1"');
        final otd = OnThisDayRepository(db, source);
        expect(await otd.today(now), isNotNull);
        expect(server.requests.single.queryParameters, {'date': mmdd});
        expect((await db.contentCacheDao.doc('otd:$mmdd'))!.etag, '"o1"');

        expect(await otd.today(now), isNotNull);
        expect(server.requests.last.headers['If-None-Match'], '"o1"');

        server.offline = true;
        expect(await otd.today(now), isNotNull);
      },
    );

    test('On This Day 503 with no copy hides the card', () async {
      server.routes['/v1/on-this-day'] = (_) => Reply(
        503,
        jsonEncode(errorExample('upstream_unavailable')),
        {'retry-after': '600'},
      );
      expect(
        await OnThisDayRepository(db, source).today(DateTime.now()),
        isNull,
      );
    });

    test('credits: cached with ETag, 304, offline copy', () async {
      final body = readFile('../docs/examples/credits.json');
      server.serve('/v1/credits', body, '"k1"');
      final credits = CreditsRepository(db, source, _NoBundle());
      expect(await credits.content(), isNotNull);
      expect(await credits.content(), isNotNull);
      expect(server.requests.last.headers['If-None-Match'], '"k1"');
      server.offline = true;
      expect(await credits.content(), isNotNull);
    });
  });
}

/// Credits content never reads the bundle (fonts do).
class _NoBundle implements AssetBundle {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
