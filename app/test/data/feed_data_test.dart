// feed_state writes (CONTRACTS 5.1, 7.2), the pools, and On This Day (2.7).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/models/catalogue.dart';
import 'package:maximus/data/models/on_this_day.dart';
import 'package:maximus/data/providers.dart';
import 'package:maximus/data/repositories/content_repository.dart';
import 'package:maximus/data/repositories/content_source.dart';
import 'package:maximus/data/repositories/feed_repository.dart';
import 'package:maximus/data/repositories/on_this_day_repository.dart';

class FileSource implements ContentSource, FeedSource {
  @override
  Future<String> catalogueJson() async =>
      File('assets/dev/catalogue.json').readAsStringSync();

  @override
  Future<String> titleJson(String id) async {
    final f = File('assets/dev/$id.json');
    if (!f.existsSync()) throw TitleNotFound(id);
    return f.readAsStringSync();
  }

  @override
  Future<String> feedJson(List<String> titleIds, {int limit = 10}) async =>
      File('assets/dev/feed.json').readAsStringSync();
}

class FakeOtd implements OnThisDaySource {
  FakeOtd(this.body);
  String? body;

  @override
  Future<String> onThisDayJson(String mmdd) async =>
      body ?? (throw const SocketException('offline'));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  var clockNow = DateTime(2026, 11, 21, 9);
  setUp(() {
    clockNow = DateTime(2026, 11, 21, 9);
    db = AppDatabase(NativeDatabase.memory(), clock: () => clockNow);
  });
  tearDown(() => db.close());

  Future<FeedStateRow> row(String id) =>
      (db.select(db.feedState)..where((t) => t.factId.equals(id))).getSingle();

  group('feed_state', () {
    const f = 'roman-history.f001', t = 'roman-history';

    test('save toggles and keeps the reaction', () async {
      final dao = db.userStateDao;
      await dao.toggleFactReaction(factId: f, titleId: t, value: 1);
      await dao.toggleFactSaved(factId: f, titleId: t);
      expect((await row(f)).saved, isTrue);
      expect((await row(f)).reaction, 1);
      await dao.toggleFactSaved(factId: f, titleId: t);
      expect((await row(f)).saved, isFalse);
      expect((await row(f)).reaction, 1);
    });

    test('like and dislike replace each other; a re-tap clears', () async {
      final dao = db.userStateDao;
      expect(await dao.toggleFactReaction(factId: f, titleId: t, value: 1), 1);
      expect(
        await dao.toggleFactReaction(factId: f, titleId: t, value: -1),
        -1,
      );
      expect(await dao.toggleFactReaction(factId: f, titleId: t, value: -1), 0);
      expect((await row(f)).reaction, 0);
    });

    test('seen keeps saved and reaction', () async {
      final dao = db.userStateDao;
      await dao.toggleFactSaved(factId: f, titleId: t);
      await dao.toggleFactReaction(factId: f, titleId: t, value: -1);
      await dao.markFactSeen(factId: f, titleId: t);
      final r = await row(f);
      expect(r.seenAt, isNotNull);
      expect(r.saved, isTrue);
      expect(r.reaction, -1);
    });

    test('a like reaches match % (CONTRACTS 6.1)', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentSourceProvider.overrideWithValue(FileSource()),
        ],
      );
      addTearDown(container.dispose);
      final subs = [
        container.listen(feedStateProvider, (_, _) {}),
        container.listen(matchProvider, (_, _) {}),
      ];
      await container.read(catalogueProvider.future);
      await container.read(feedStateProvider.future);
      expect(container.read(matchProvider).badges, isFalse);

      await db.userStateDao.toggleFactReaction(factId: f, titleId: t, value: 1);
      await pumpEventQueue();
      final match = container.read(matchProvider);
      expect(match.badges, isTrue);
      expect(match.pctOf(t), greaterThan(50));
      for (final s in subs) {
        s.close();
      }
    });
  });

  group('pools', () {
    late Catalogue catalogue;
    late FeedRepository repo;

    setUp(() async {
      final source = FileSource();
      catalogue = Catalogue.fromJson(
        jsonDecode(await source.catalogueJson()) as Map<String, dynamic>,
      );
      repo = FeedRepository(ContentRepository(db, source), source);
    });

    test('own facts carry the lesson and image', () async {
      final own = await repo.ownEntries(catalogue, ['shivaji-maharaj']);
      expect(own, hasLength(2));
      expect(own.every((e) => !e.isTry), isTrue);
      expect(own.every((e) => e.lessonId == 'shivaji-maharaj.l01'), isTrue);
      expect(
        own.firstWhere((e) => e.fact.id == 'shivaji-maharaj.f001').image?.id,
        'shivaji-maharaj.i01',
      );
    });

    test('an unknown title is skipped', () async {
      expect(await repo.ownEntries(catalogue, ['nope']), isEmpty);
    });

    test('try facts only for the asked titles, with no lesson', () async {
      final tries = await repo.tryEntries(catalogue, ['chanakya']);
      expect(tries, isNotEmpty);
      expect(tries.every((e) => e.title.id == 'chanakya'), isTrue);
      expect(tries.every((e) => e.isTry && e.lessonId == null), isTrue);
    });
  });

  group('On This Day', () {
    final body = File('assets/dev/on-this-day.json').readAsStringSync();
    final nov21 = DateTime(2026, 11, 21, 9);

    test('features the first linked item, BCE years read well', () {
      final otd = OnThisDay.fromJson(jsonDecode(body) as Map<String, dynamic>);
      expect(otd.featured.linkedTitleId, 'roman-history');
      expect(otd.featured.titleLine, '44 BCE · Roman Republic');
      expect(otd.items.first.titleLine, startsWith('1783 · '));
      expect(otd.caption, 'From Wikipedia · CC BY-SA 4.0');
    });

    test('a different date hides the card', () async {
      final repo = OnThisDayRepository(db, FakeOtd(body));
      expect(await repo.today(DateTime(2026, 11, 23)), isNull);
    });

    test('survives going offline the same day', () async {
      final source = FakeOtd(body);
      final repo = OnThisDayRepository(db, source);
      clockNow = nov21;
      expect(await repo.today(nov21), isNotNull);
      source.body = null;
      expect(await repo.today(nov21.add(const Duration(hours: 3))), isNotNull);
    });

    test('last year\'s cached copy is not a same-day copy', () async {
      final source = FakeOtd(body);
      final repo = OnThisDayRepository(db, source);
      clockNow = DateTime(2025, 11, 21, 9);
      expect(await repo.today(DateTime(2025, 11, 21, 9)), isNotNull);
      source.body = null;
      expect(await repo.today(nov21), isNull);
    });

    test('offline with no copy hides the card', () async {
      final repo = OnThisDayRepository(db, FakeOtd(null));
      expect(await repo.today(nov21), isNull);
    });
  });
}
