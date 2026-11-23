// S8 done-condition as widget tests: the feed pages, Save / Like / Dislike
// persist and reach match %, Go deeper opens the right place.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/theme/app_theme.dart';
import 'package:maximus/core/theme/tokens.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/providers.dart';
import 'package:maximus/data/repositories/on_this_day_repository.dart';
import 'package:maximus/features/feed/feed_card.dart';
import 'package:maximus/features/on_this_day/on_this_day_card.dart';

import '../app_harness.dart';
import '../helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await AppHarness.settle(tester);
}

/// The button on the card that is actually on screen.
Finder onCard(String label) => find.bySemanticsLabel(label).hitTestable();

Future<List<FeedStateRow>> feedRows(WidgetTester tester, AppHarness h) =>
    AppHarness.run(tester, h.db.select(h.db.feedState).get);

Future<void> swipeUp(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(0, -500), 1500);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await AppHarness.settle(tester);
}

void main() {
  testWidgets('cold start shows try cards from the sample feed', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(tester);
    await tapAndSettle(tester, find.text('Feed'));
    expect(find.byType(FeedCard), findsWidgets);
    expect(find.textContaining('SAMPLE:').hitTestable(), findsOneWidget);
    expect(find.text('Go deeper').hitTestable(), findsOneWidget);
  });

  testWidgets('empty state when nothing can be shown', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    // Rate every title down: no own facts and no try titles are left.
    final c = containerOf(tester);
    final catalogue = await AppHarness.run(
      tester,
      () => c.read(catalogueProvider.future),
    );
    for (final t in catalogue.titles) {
      await AppHarness.run(tester, () => h.db.userStateDao.setRating(t.id, -1));
    }
    await tapAndSettle(tester, find.text('Feed'));
    expect(find.text('Your feed is empty'), findsOneWidget);
    await tapAndSettle(tester, find.text('Browse the library'));
    expect(find.text('Ancient and medieval'), findsOneWidget);
  });

  testWidgets('Save and Like persist and move match %', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await tapAndSettle(tester, find.text('Feed'));

    final c = containerOf(tester);
    final before = c.read(matchProvider).pctOf('roman-history')!;

    await tapAndSettle(tester, onCard('Save'));
    await tapAndSettle(tester, onCard('Like'));
    final rows = await feedRows(tester, h);
    final row = rows.single;
    expect(row.saved, isTrue);
    expect(row.reaction, 1);
    expect(c.read(matchProvider).pctOf('roman-history')!, greaterThan(before));

    await tapAndSettle(tester, onCard('Like'));
    expect((await feedRows(tester, h)).single.reaction, 0);
    expect((await feedRows(tester, h)).single.saved, isTrue);
  });

  testWidgets('Dislike moves on and the fact does not come back', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await tapAndSettle(tester, find.text('Feed'));

    String shown() =>
        tester.widget<Text>(find.textContaining('SAMPLE:').hitTestable()).data!;
    final first = shown();
    await tester.tap(onCard('Dislike'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await AppHarness.settle(tester);
    expect(shown(), isNot(first));

    final disliked = (await feedRows(tester, h)).where((r) => r.reaction == -1);
    expect(disliked, hasLength(1));

    for (var i = 0; i < 9; i++) {
      await swipeUp(tester);
      expect(shown(), isNot(first));
    }
  });

  testWidgets('a card on screen for 1 s is marked seen', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await tapAndSettle(tester, find.text('Feed'));
    await tester.pump(const Duration(milliseconds: 1100));
    await AppHarness.settle(tester);
    final rows = await feedRows(tester, h);
    expect(rows, hasLength(1));
    expect(rows.single.seenAt, isNotNull);
  });

  testWidgets('Go deeper: own card opens the lesson', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await tapAndSettle(tester, find.text('Feed'));
    await tapAndSettle(tester, find.text('Go deeper').hitTestable());
    expect(find.textContaining(RegExp(r'^Lesson \d of 6$')), findsOneWidget);
  });

  testWidgets('Go deeper: try card opens the title sheet', (tester) async {
    usePixel8(tester);
    await AppHarness.pump(tester);
    await tapAndSettle(tester, find.text('Feed'));
    await tapAndSettle(tester, find.text('Go deeper').hitTestable());
    expect(find.text('Add to study list'), findsOneWidget);
  });

  testWidgets('saved state stays in drift after the screen is gone', (tester) async {
    usePixel8(tester);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final h = await AppHarness.pump(tester, db: db);
    await AppHarness.run(
      tester,
      () => db.userStateDao.addToStudyList('roman-history'),
    );
    await tapAndSettle(tester, find.text('Feed'));
    await tapAndSettle(tester, onCard('Save'));
    final saved = (await feedRows(tester, h)).single.factId;

    await tester.pumpWidget(const SizedBox.shrink());
    await AppHarness.settle(tester);
    final rows = await AppHarness.run(tester, db.select(db.feedState).get);
    expect(rows.single.factId, saved);
    expect(rows.single.saved, isTrue);
  });

  group('On This Day card', () {
    Future<AppDatabase> pumpCard(WidgetTester tester, DateTime now) async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory(), clock: () => now);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            onThisDaySourceProvider.overrideWithValue(_SyncOtd()),
          ],
          child: MaterialApp(
            theme: MxTheme.build(MxThemeVariant.dark),
            home: Scaffold(body: OnThisDayCard(now: now)),
          ),
        ),
      );
      await AppHarness.settle(tester);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await AppHarness.settle(tester);
        await AppHarness.run(tester, db.close);
      });
      return db;
    }

    testWidgets('shows the linked item with kicker and attribution', (
      tester,
    ) async {
      await pumpCard(tester, DateTime(2026, 11, 21, 9));
      expect(find.text('ON THIS DAY · 21 NOVEMBER'), findsOneWidget);
      expect(find.text('44 BCE · Roman Republic'), findsOneWidget);
      expect(find.text('From Wikipedia · CC BY-SA 4.0'), findsOneWidget);
    });

    testWidgets('is hidden on any other date', (tester) async {
      await pumpCard(tester, DateTime(2026, 11, 23, 9));
      expect(find.textContaining('ON THIS DAY'), findsNothing);
    });
  });
}

class _SyncOtd implements OnThisDaySource {
  @override
  Future<String> onThisDayJson(String mmdd) =>
      Future.value(File('assets/dev/on-this-day.json').readAsStringSync());
}
