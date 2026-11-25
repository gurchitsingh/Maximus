// S6 done-condition as widget tests (SESSION_PROMPTS S6): add a sample title
// to the study list, read a lesson, rate it, and the match % changes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/widgets/widgets.dart';
import 'package:maximus/data/providers.dart';

import '../app_harness.dart';
import '../helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

void main() {
  testWidgets('Library -> sheet: add to study list, rate, match % moves', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);

    await tapAndSettle(tester, find.text('Library'));
    expect(find.text('For you'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ancient and medieval'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ancient and medieval'), findsOneWidget);
    // The people row sits below the fold of the lazy list.
    await tester.scrollUntilVisible(
      find.text('Think Like...'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Think Like...'), findsOneWidget);
    // Cold start: no badges anywhere (CONTRACTS 6.2).
    expect(find.textContaining('% match'), findsNothing);

    await tapAndSettle(tester, find.bySemanticsLabel('ROMAN HISTORY').first);
    expect(find.text('Add to study list'), findsOneWidget);
    expect(find.text('6 lessons · 14 min'), findsOneWidget);
    expect(find.text('How does it look?'), findsOneWidget);

    await tapAndSettle(tester, find.text('Add to study list'));
    expect(find.text('Added to study list'), findsOneWidget);
    // Adding alone does not change Start (it needs a lesson marked read).
    expect(find.text('Start'), findsWidgets);
    final rows = await AppHarness.run(tester, h.db.select(h.db.studyList).get);
    expect(rows.single.titleId, 'roman-history');

    final c = containerOf(tester);
    final before = c.read(matchProvider);
    expect(before.badges, isTrue);
    final chanakyaBefore = before.pctOf('chanakya')!;
    expect(
      find.textContaining(
        '${before.pctOf('roman-history')}% match',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.bySemanticsLabel('Like'));
    expect(find.text('Noted. Similar topics move up.'), findsOneWidget);
    final ratings = await AppHarness.run(tester, h.db.select(h.db.ratings).get);
    expect(ratings.single.value, 1);
    final after = c.read(matchProvider);
    expect(
      after.pctOf('roman-history')!,
      greaterThan(before.pctOf('roman-history')!),
    );
    expect(after.pctOf('chanakya')!, greaterThanOrEqualTo(chanakyaBefore));

    // Re-tapping the chosen thumb clears the rating.
    await tapAndSettle(tester, find.bySemanticsLabel('Like'));
    expect(find.text('How does it look?'), findsOneWidget);
    expect(
      // A removed rating is a tombstone until synced (CONTRACTS 15.5).
      await AppHarness.run(
        tester,
        (h.db.select(h.db.ratings)..where((t) => t.deleted.equals(false))).get,
      ),
      isEmpty,
    );

    await h.dispose(tester);
  });

  testWidgets('Reader: next marks lessons read; finishing celebrates', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);

    await tapAndSettle(tester, find.text('Library'));
    await tapAndSettle(tester, find.bySemanticsLabel('ROMAN HISTORY').first);
    await tapAndSettle(tester, find.text('Start').last);
    expect(find.text('Lesson 1 of 6'), findsOneWidget);
    expect(find.text('A village on seven hills'), findsOneWidget);
    // Topic bar replaces the main nav; Quiz shows (10 >= 6 questions).
    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.textContaining('Text adapted from'), findsWidgets);

    await tapAndSettle(tester, find.bySemanticsLabel('Listen to this lesson'));
    expect(h.tts.spoken.single, startsWith('A village on seven hills.'));

    for (var i = 1; i < 6; i++) {
      await tapAndSettle(tester, find.bySemanticsLabel('Next lesson'));
      expect(find.text('Lesson ${i + 1} of 6'), findsOneWidget);
    }
    var progress = await AppHarness.run(
      tester,
      h.db.select(h.db.lessonProgress).get,
    );
    expect(progress.where((r) => r.completedAt != null), hasLength(5));

    await tapAndSettle(tester, find.bySemanticsLabel('Finish lesson'));
    expect(find.text('Topic finished'), findsOneWidget);
    expect(find.text('Take the quiz'), findsOneWidget);
    progress = await AppHarness.run(
      tester,
      h.db.select(h.db.lessonProgress).get,
    );
    expect(progress.where((r) => r.completedAt != null), hasLength(6));

    await tapAndSettle(tester, find.text('Not now'));
    expect(find.text('Topic finished'), findsNothing);

    // Back leaves the topic; Home now shows the resume card.
    await tapAndSettle(tester, find.bySemanticsLabel('Back'));
    await tapAndSettle(tester, find.text('Home'));
    expect(find.textContaining('CONTINUE · ROMAN HISTORY'), findsOneWidget);
    // Reading signals switch the badges on (lessons read, CONTRACTS 6.1).
    expect(containerOf(tester).read(matchProvider).badges, isTrue);

    await h.dispose(tester);
  });

  testWidgets('Lessons list sheet jumps to a lesson', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await tapAndSettle(tester, find.text('Library'));
    await tapAndSettle(tester, find.bySemanticsLabel('ROMAN HISTORY').first);
    await tapAndSettle(tester, find.text('Start').last);

    await tapAndSettle(tester, find.bySemanticsLabel('All lessons'));
    expect(find.text('0 of 6 read'), findsOneWidget);
    await tapAndSettle(tester, find.bySemanticsLabel(RegExp('^Lesson 4:')));
    expect(find.text('Lesson 4 of 6'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Study list: rows, progress, remove with X and empty state', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await AppHarness.run(tester, () async {
      await h.db.userStateDao.addToStudyList('chanakya');
      await h.db.userStateDao.addToStudyList('roman-history');
      await h.db.userStateDao.completeLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      );
    });
    await tapAndSettle(tester, find.text('Library'));
    expect(find.text('Your study list'), findsWidgets);
    expect(find.text('Lesson 2 of 6'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);

    await tapAndSettle(tester, find.bySemanticsLabel('Remove Roman history'));
    expect(find.text('Lesson 2 of 6'), findsNothing);
    await tapAndSettle(tester, find.bySemanticsLabel('Remove Chanakya'));
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Browse the library'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Home lists study rows and For you skips added titles', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await AppHarness.settle(tester);
    expect(find.text('Your study list'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Your quiz scores'), findsOneWidget);
    // Roman history is on the list, so the For you row leaves it out.
    expect(find.bySemanticsLabel(RegExp('^ROMAN HISTORY')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^CHANAKYA')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('theme and text size persist in drift settings', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await tapAndSettle(tester, find.bySemanticsLabel('Settings'));
    await tapAndSettle(tester, find.text('Sepia'));
    await tapAndSettle(tester, find.text('Large'));
    await tapAndSettle(tester, find.text('1.2x'));
    final s = await AppHarness.run(tester, h.db.settingsDao.readAll);
    expect(s['theme'], 'sepia');
    expect(s['text_size'], 'large');
    expect(s['voice_speed'], '1.2');
    await h.dispose(tester);
  });

  testWidgets('sheet button: Start, Continue after a read lesson, Read again', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    Future<void> complete(int i) => AppHarness.run(
      tester,
      () => h.db.userStateDao.completeLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l0$i',
        lessonIndex: i,
      ),
    );
    final sheetButton = find.descendant(
      of: find.byType(TintButton),
      matching: find.byType(Text),
    );
    String label() => (tester.widget<Text>(sheetButton.last)).data!;

    await tapAndSettle(tester, find.text('Library'));
    await tapAndSettle(tester, find.bySemanticsLabel('ROMAN HISTORY').first);
    expect(label(), 'Start');

    // Opened but not finished is still Start.
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.openLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      ),
    );
    await AppHarness.settle(tester);
    expect(label(), 'Start');

    await complete(1);
    await AppHarness.settle(tester);
    expect(label(), 'Continue');

    for (var i = 2; i <= 6; i++) {
      await complete(i);
    }
    await AppHarness.settle(tester);
    expect(label(), 'Read again');

    // Read again opens lesson 1.
    await tapAndSettle(tester, find.text('Read again'));
    expect(find.text('Lesson 1 of 6'), findsOneWidget);
  });
}
