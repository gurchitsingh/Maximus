// SyncService (CONTRACTS 15.5) against the fake /v1/me/sync: push then
// pull, last write wins both ways, tombstones, acks, single-flight,
// backoff, 401 refresh and retry, fresh-device hydrate. No network.
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/api/auth_tokens.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/sync/sync_api.dart';
import 'package:maximus/data/sync/sync_dao.dart';
import 'package:maximus/data/sync/sync_record.dart';
import 'package:maximus/data/sync/sync_service.dart';

import '../../fakes/fake_auth.dart';
import '../../fakes/fake_sync.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeAuthBackend backend;
  late FakeUser ada;
  late MemoryTokenStore store;
  late AuthTokens tokens;
  late AppDatabase db;
  late SyncService sync;
  late DateTime now;
  Map<String, String>? pulledSettings;

  late FakeSyncServer server;

  SyncService make({Duration debounce = const Duration(seconds: 5)}) =>
      SyncService(
        db: db,
        api: SyncApi(fakeApiClient(backend, tokens)),
        userId: () => store.read(TokenKeys.userId),
        onSettingsPulled: (s) => pulledSettings = s,
        debounce: debounce,
      );

  setUp(() async {
    backend = FakeAuthBackend();
    server = backend.sync;
    ada = backend.addUser('ada@example.com');
    store = MemoryTokenStore({
      TokenKeys.refreshToken: backend.issueRefresh(ada.email),
      TokenKeys.userId: ada.id,
    });
    tokens = AuthTokens(store);
    now = DateTime.utc(2026, 11, 25, 10);
    db = AppDatabase(NativeDatabase.memory(), clock: () => now);
    await db.settingsDao.readAll();
    pulledSettings = null;
    sync = make();
  });

  tearDown(() async {
    sync.dispose();
    tokens.dispose();
    await db.close();
  });

  Future<RatingRow?> rating(String id) => (db.select(
    db.ratings,
  )..where((t) => t.titleId.equals(id))).getSingleOrNull();

  Map<String, dynamic> ratingData(String id, int v, DateTime at) => {
    'title_id': id,
    'value': v,
    'rated_at': zTime(at),
  };

  List<String> syncCalls() => [
    for (final c in backend.calls)
      if (c.contains('/me/sync')) c,
  ];

  test('push, then pull: both sides end with both changes', () async {
    await db.userStateDao.setRating('roman-history', 1);
    server.put(ada.id, SyncKind.studyItem, 'chanakya', {
      'title_id': 'chanakya',
      'added_at': '2026-11-24T09:00:00Z',
    }, DateTime.utc(2026, 11, 24, 9));

    sync.start();
    expect(await sync.syncNow(), SyncResult.ok);

    expect(syncCalls().first, 'POST /v1/me/sync');
    expect(syncCalls().last, 'GET /v1/me/sync');
    expect(server.live(ada.id, SyncKind.rating).single.data!['value'], 1);
    expect(
      (await db.userStateDao.watchStudyList().first).single.titleId,
      'chanakya',
    );
    expect(await db.syncDao.dirtyCount(), 0);
    expect(await db.syncDao.cursor(), greaterThan(0));
    expect(await db.syncDao.stateValue(SyncStateKeys.lastSyncAt), isNotNull);
  });

  test('last write wins, device to server: the newer local edit is '
      'applied', () async {
    server.put(
      ada.id,
      SyncKind.rating,
      'chanakya',
      ratingData('chanakya', -1, now),
      now.subtract(const Duration(hours: 1)),
    );
    await db.userStateDao.setRating('chanakya', 1);
    sync.start();
    await sync.syncNow();
    expect(server.record(ada.id, SyncKind.rating, 'chanakya')!.data!['value'], 1);
    expect((await rating('chanakya'))!.value, 1);
  });

  test('last write wins, server to device: a newer server copy beats the '
      'local edit (superseded)', () async {
    await db.userStateDao.setRating('chanakya', 1);
    final later = now.add(const Duration(hours: 1));
    server.put(
      ada.id,
      SyncKind.rating,
      'chanakya',
      ratingData('chanakya', -1, later),
      later,
    );
    sync.start();
    await sync.syncNow();
    expect(server.record(ada.id, SyncKind.rating, 'chanakya')!.data!['value'], -1);
    final r = (await rating('chanakya'))!;
    expect((r.value, r.dirty), (-1, false));
  });

  test('tombstone push: the server gets the delete, then the row is gone', () async {
    await db.userStateDao.addToStudyList('roman-history');
    sync.start();
    await sync.syncNow();
    now = now.add(const Duration(minutes: 1));
    await db.userStateDao.removeFromStudyList('roman-history');
    await sync.syncNow();
    final stored = server.record(ada.id, SyncKind.studyItem, 'roman-history')!;
    expect((stored.deleted, stored.data), (true, null));
    expect(await db.select(db.studyList).get(), isEmpty);
  });

  test('tombstone pull: a delete from another device removes the row', () async {
    await db.userStateDao.addToStudyList('roman-history');
    sync.start();
    await sync.syncNow();
    server.put(
      ada.id,
      SyncKind.studyItem,
      'roman-history',
      null,
      now.add(const Duration(minutes: 1)),
      deleted: true,
    );
    await sync.syncNow();
    expect(await db.select(db.studyList).get(), isEmpty);
  });

  test('dirty is cleared only after the server acknowledges', () async {
    await db.userStateDao.setRating('chanakya', 1);
    sync.start();

    backend.offline = true;
    expect(await sync.syncNow(), SyncResult.offline);
    expect(await db.syncDao.dirtyCount(), 1);

    backend.offline = false;
    server
      ..loseAcks =
          true // applied, but the answer never says so
      ..failPulls = true; // and no pull reads it back
    expect(await sync.syncNow(), SyncResult.failed);
    expect(await db.syncDao.dirtyCount(), 1);

    // Reading back exactly the pushed version also confirms it.
    server.failPulls = false;
    expect(await sync.syncNow(), SyncResult.ok);
    expect(await db.syncDao.dirtyCount(), 0);

    // A normal ack.
    server.loseAcks = false;
    now = now.add(const Duration(minutes: 1));
    await db.userStateDao.setRating('chanakya', -1);
    await sync.syncNow();
    expect(await db.syncDao.dirtyCount(), 0);
  });

  test('single-flight: overlapping triggers never run two syncs at once',
      () async {
    await db.userStateDao.setRating('chanakya', 1);
    sync.start(trigger: SyncTrigger.manual);
    final gate = Completer<void>();
    server.gate = gate.future;
    await pumpEventQueue();

    var inFlight = 0, maxInFlight = 0;
    sync.status.addListener(() {
      inFlight = sync.status.value.running ? 1 : 0;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
    });
    final a = sync.syncNow();
    final b = sync.sync(SyncTrigger.resume);
    final c = sync.sync(SyncTrigger.online);
    await pumpEventQueue();
    // Only the first run's push is waiting at the gate.
    expect(syncCalls(), ['POST /v1/me/sync']);
    server.gate = null;
    gate.complete();
    final results = await Future.wait([a, b, c]);
    expect(results, everyElement(SyncResult.ok));
    // The joined requests make exactly one follow-up run, after the first.
    expect(syncCalls().where((c) => c.startsWith('GET')), hasLength(2));
    expect(maxInFlight, 1);
  });

  test('backoff: 30 s, 2 min, then capped at 10 min; local writes wait it '
      'out, the network coming back does not', () async {
    server.failures.addAll([
      (500, 'internal_error'),
      (500, 'internal_error'),
      (503, 'internal_error'),
      (500, 'internal_error'),
    ]);
    sync.start(trigger: SyncTrigger.manual);
    Future<Duration> failOnce(SyncTrigger t) async {
      expect(await sync.sync(t), SyncResult.failed);
      return sync.retryAt!.difference(now);
    }

    // The start run is the first failure.
    await pumpEventQueue();
    while (sync.status.value.running) {
      await pumpEventQueue();
    }
    expect(sync.failures, 1);
    expect(sync.retryAt!.difference(now), const Duration(seconds: 30));
    expect(await sync.sync(SyncTrigger.localWrite), SyncResult.skipped);
    expect(await failOnce(SyncTrigger.retry), const Duration(minutes: 2));
    expect(await failOnce(SyncTrigger.online), const Duration(minutes: 10));
    expect(await failOnce(SyncTrigger.manual), const Duration(minutes: 10));

    // Once it works, the backoff resets.
    expect(await sync.syncNow(), SyncResult.ok);
    expect((sync.failures, sync.retryAt), (0, null));
  });

  test('offline is silent and keeps everything', () async {
    await db.userStateDao.setRating('chanakya', 1);
    backend.offline = true;
    sync.start();
    expect(await sync.syncNow(), SyncResult.offline);
    expect(sync.status.value.last, SyncResult.offline);
    expect((await rating('chanakya'))!.value, 1);
    expect(store.values, contains(TokenKeys.refreshToken));
  });

  test('401: the token is refreshed once and the call retried', () async {
    await db.userStateDao.setRating('chanakya', 1);
    sync.start();
    await sync.syncNow();
    backend.expireAccessTokens();
    now = now.add(const Duration(minutes: 20));
    await db.userStateDao.setRating('chanakya', -1);
    backend.calls.clear();

    expect(await sync.syncNow(), SyncResult.ok);
    expect(backend.calls.take(3), [
      'POST /v1/me/sync', // token_expired
      'POST /v1/auth/refresh',
      'POST /v1/me/sync', // retried with the new token
    ]);
    expect(server.record(ada.id, SyncKind.rating, 'chanakya')!.data!['value'], -1);
  });

  test('401 with a refused refresh: session ends, local data stays, no '
      'retries', () async {
    await db.userStateDao.setRating('chanakya', 1);
    backend.refreshFailure = (401, 'token_invalid');
    var ended = false;
    tokens.sessionEnded.listen((_) => ended = true);
    sync.start(trigger: SyncTrigger.manual);
    expect(await sync.syncNow(), SyncResult.unauthorized);
    await pumpEventQueue();
    expect(ended, isTrue, reason: 'the auth controller routes to Sign in');
    expect(store.values, isEmpty);
    expect((await rating('chanakya'))!.dirty, isTrue);
    expect(sync.retryAt, isNull);
  });

  test('fresh device: the first pull hydrates everything and skips '
      'onboarding when the account has picks', () async {
    final at = DateTime.utc(2026, 11, 20);
    server
      ..put(ada.id, SyncKind.interest, 'topic_pick:roman-history', {
        'kind': 'topic_pick',
        'title_id': 'roman-history',
        'position': 0,
        'picked_at': zTime(at),
      }, at)
      ..put(ada.id, SyncKind.setting, 'theme', {'value': 'light'}, at)
      ..put(
        ada.id,
        SyncKind.rating,
        'chanakya',
        ratingData('chanakya', 1, at),
        at,
      )
      ..put(ada.id, SyncKind.progress, 'roman-history.l01', {
        'lesson_id': 'roman-history.l01',
        'title_id': 'roman-history',
        'lesson_index': 1,
        'last_opened_at': zTime(at),
        'completed_at': null,
      }, at);

    final hydrating = <bool>[];
    sync.status.addListener(() => hydrating.add(sync.status.value.hydrating));
    sync.start();
    await pumpEventQueue();
    expect(await sync.syncNow(), SyncResult.ok);

    expect(hydrating, contains(true));
    expect(sync.status.value.hydrating, isFalse);
    expect(server.pushes.expand((p) => p).map((r) => r['id']), [
      'onboarding_done',
    ], reason: 'a fresh phone pushes nothing but the onboarding skip');
    expect((await db.userStateDao.watchInterests().first).single.titleId,
        'roman-history');
    expect(await db.settingsDao.read(SettingKeys.theme), 'light');
    expect(await db.settingsDao.read(SettingKeys.onboardingDone), 'true');
    expect(pulledSettings?[SettingKeys.theme], 'light');
    expect((await rating('chanakya'))!.value, 1);
    expect(await db.userStateDao.watchProgress().first, hasLength(1));
  });

  test('reset: a cursor older than the tombstone horizon pulls from 0',
      () async {
    sync.start();
    server.put(ada.id, SyncKind.rating, 'chanakya',
        ratingData('chanakya', 1, now), now);
    await sync.syncNow();
    await db.syncDao.setCursor(1);
    server.purgedSeq[ada.id] = 5;
    server.pulls.clear();
    expect(await sync.syncNow(), SyncResult.ok);
    expect(server.pulls, [1, 0]);
  });

  test('another account signing in on this phone never gets the last '
      "account's rows", () async {
    await db.syncDao.setStateValue(SyncStateKeys.userId, 'someone-else');
    await db.userStateDao.setRating('chanakya', 1);
    sync.start();
    await sync.syncNow();
    expect(server.live(ada.id, SyncKind.rating), isEmpty);
    expect(await rating('chanakya'), isNull);
    expect(await db.syncDao.stateValue(SyncStateKeys.userId), ada.id);
  });

  test('a local write syncs after the debounce, coalesced', () async {
    sync.dispose();
    sync = make(debounce: const Duration(milliseconds: 80));
    sync.start();
    while (sync.status.value.running || sync.status.value.last == SyncResult.skipped) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    server.pushes.clear();
    await db.userStateDao.setRating('chanakya', 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await db.userStateDao.addToStudyList('chanakya');
    expect(server.pushes, isEmpty, reason: 'still inside the debounce');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.pushes, hasLength(1));
    expect(server.pushes.single, hasLength(2));
    expect(await db.syncDao.dirtyCount(), 0);
  });

  test('stop: a run in flight writes nothing after it', () async {
    server.put(ada.id, SyncKind.rating, 'chanakya',
        ratingData('chanakya', 1, now), now);
    final gate = Completer<void>();
    server.gate = gate.future;
    sync.start();
    await pumpEventQueue();
    final stopped = sync.stop();
    server.gate = null;
    gate.complete();
    await stopped;
    expect(await rating('chanakya'), isNull);
    expect(await sync.syncNow(), SyncResult.skipped);
  });
}
