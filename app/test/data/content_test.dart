// JSON models, dev assets, content repository and progress (CONTRACTS 10
// "App data"). Contract files are read from ../docs and ../backend.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/models/catalogue.dart';
import 'package:maximus/data/models/title.dart';
import 'package:maximus/data/providers.dart';
import 'package:maximus/data/repositories/content_repository.dart';
import 'package:maximus/data/repositories/content_source.dart';
import 'package:maximus/data/repositories/user_state_repository.dart';
import 'package:maximus/domain/match/match_scores.dart';
import 'package:maximus/domain/match/rows.dart';

const sampleIds = ['roman-history', 'shivaji-maharaj', 'chanakya'];

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

class FakeSource implements ContentSource {
  int titleCalls = 0;
  bool fail = false;

  @override
  Future<String> catalogueJson() async {
    if (fail) throw Exception('offline');
    return File('assets/dev/catalogue.json').readAsString();
  }

  @override
  Future<String> titleJson(String id) async {
    titleCalls++;
    if (fail) throw Exception('offline');
    final f = File('assets/dev/$id.json');
    if (!f.existsSync()) throw TitleNotFound(id);
    return f.readAsString();
  }
}

void main() {
  group('models', () {
    for (final id in sampleIds) {
      test('parses sample $id', () {
        final t = TitleDetail.fromJson(
          readJson('../backend/data/samples/$id.json'),
        );
        expect(t.id, id);
        expect(t.lessons, isNotEmpty);
        expect(t.summary.lessonCount, t.lessons.length);
        expect([
          for (final l in t.lessons) l.index,
        ], List.generate(t.lessons.length, (i) => i + 1));
        expect(t.person == null, t.summary.kind == 'topic');
        for (final l in t.lessons) {
          for (final i in l.imageIds) {
            expect(t.image(i), isNotNull, reason: '$id image $i');
          }
          for (final s in l.sourceIds) {
            expect(t.source(s), isNotNull, reason: '$id source $s');
          }
        }
      });
    }

    test('parses docs/examples/catalogue.json', () {
      final c = Catalogue.fromJson(readJson('../docs/examples/catalogue.json'));
      expect(c.groups, hasLength(12));
      expect([for (final g in c.groups) g.order], List.generate(12, (i) => i));
      expect(c.titles.map((t) => t.id).toSet(), sampleIds.toSet());
      expect(c.title(c.featuredId!), isNotNull);
      expect(c.peopleRowLabel, isNotEmpty);
    });

    test('unknown fields are ignored (tolerant reader, P7)', () {
      final j = readJson('../backend/data/samples/roman-history.json')
        ..['brand_new_field'] = {'x': 1};
      (j['lessons'] as List).first['also_new'] = true;
      expect(TitleDetail.fromJson(j).id, 'roman-history');
    });
  });

  group('dev assets', () {
    test('assets/dev copies equal their sources', () {
      final pairs = {
        for (final id in sampleIds)
          'assets/dev/$id.json': '../backend/data/samples/$id.json',
        for (final n in ['catalogue', 'feed', 'on-this-day', 'credits'])
          'assets/dev/$n.json': '../docs/examples/$n.json',
      };
      pairs.forEach((copy, source) {
        expect(
          jsonDecode(File(copy).readAsStringSync()),
          jsonDecode(File(source).readAsStringSync()),
          reason: '$copy is out of date: copy $source again',
        );
      });
    });
  });

  group('content repository', () {
    late AppDatabase db;
    late FakeSource source;
    late ContentRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      source = FakeSource();
      repo = ContentRepository(db, source);
    });
    tearDown(() => db.close());

    test('a title is fetched once, then served from cached_titles', () async {
      final a = await repo.title('roman-history', catalogueVersion: 1);
      final b = await repo.title('roman-history', catalogueVersion: 1);
      expect(a.id, b.id);
      expect(source.titleCalls, 1);
      expect(await db.contentCacheDao.title('roman-history'), isNotNull);
    });

    test('a newer catalogue content_version refetches', () async {
      await repo.title('roman-history', catalogueVersion: 1);
      await repo.title('roman-history', catalogueVersion: 2);
      expect(source.titleCalls, 2);
    });

    test('offline: cached title and catalogue still load', () async {
      await repo.catalogue();
      await repo.title('chanakya');
      source.fail = true;
      expect((await repo.catalogue()).titles, hasLength(3));
      expect(
        (await repo.title('chanakya', catalogueVersion: 9)).id,
        'chanakya',
      );
    });

    test('offline and never cached: the error surfaces', () async {
      source.fail = true;
      expect(repo.title('roman-history'), throwsException);
    });
  });

  group('title progress', () {
    LessonProgressRow row(int i, {bool done = false, int t = 0}) =>
        LessonProgressRow(
          lessonId: 'roman-history.l0$i',
          titleId: 'roman-history',
          lessonIndex: i,
          lastOpenedAt: DateTime.utc(2026, 1, 1, 0, 0, t),
          completedAt: done ? DateTime.utc(2026) : null,
        );
    final lessons = TitleDetail.fromJson(
      readJson('../backend/data/samples/roman-history.json'),
    ).lessons;

    test('not started', () {
      final p = TitleProgress(
        titleId: 'roman-history',
        lessonCount: 6,
        rows: [],
      );
      expect(p.label, 'Not started');
      expect(p.fraction, 0);
      expect(p.resumeLesson(lessons).index, 1);
    });

    test('resumes after the last completed lesson', () {
      final p = TitleProgress(
        titleId: 'roman-history',
        lessonCount: 6,
        // DAO order: newest opened first.
        rows: [
          row(3, done: true, t: 3),
          row(2, done: true, t: 2),
          row(1, done: true),
        ],
      );
      expect(p.completed, 3);
      expect(p.fraction, 0.5);
      expect(p.label, 'Lesson 4 of 6');
      expect(p.resumeLesson(lessons).index, 4);
    });

    test('an opened, unfinished lesson is resumed itself', () {
      final p = TitleProgress(
        titleId: 'roman-history',
        lessonCount: 6,
        rows: [row(2, t: 5), row(1, done: true)],
      );
      expect(p.resumeIndex, 2);
    });

    test('the last lesson finished stays on the last lesson', () {
      final p = TitleProgress(
        titleId: 'roman-history',
        lessonCount: 6,
        rows: [for (var i = 6; i >= 1; i--) row(i, done: true, t: i)],
      );
      expect(p.finished, isTrue);
      expect(p.resumeIndex, 6);
    });

    test('rows of other titles and removed lessons are ignored', () {
      final p = TitleProgress(
        titleId: 'roman-history',
        lessonCount: 2,
        rows: [
          row(5, done: true, t: 9),
          LessonProgressRow(
            lessonId: 'chanakya.l01',
            titleId: 'chanakya',
            lessonIndex: 1,
            lastOpenedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026),
          ),
        ],
      );
      expect(p.completed, 0);
      expect(p.resumeIndex, 2); // clamped into 1..lessonCount
    });
  });

  group('rows', () {
    final catalogue = Catalogue.fromJson(
      readJson('../docs/examples/catalogue.json'),
    );
    final titles = [for (final t in catalogue.titles) t.toMatchTitle()];

    test('For you skips the study list; cold start is rank order', () {
      final r = matchScores(titles, MatchSignals.empty);
      expect(forYouIds(r, {}), [for (final t in catalogue.titles) t.id]);
      expect(forYouIds(r, {'roman-history'}), isNot(contains('roman-history')));
    });

    test('Because you liked X: only similar titles, never X', () {
      final r = matchScores(
        titles,
        const MatchSignals(ratings: {'chanakya': 1}),
      );
      final ids = becauseYouLikedIds(titles, 'chanakya', r);
      expect(ids, isNot(contains('chanakya')));
      for (final id in ids) {
        final t = titles.firstWhere((x) => x.id == id);
        expect(
          jaccard(t.tags, titles.firstWhere((x) => x.id == 'chanakya').tags),
          greaterThan(0),
        );
      }
      expect(becauseYouLikedIds(titles, 'unknown', r), isEmpty);
    });
  });
}
