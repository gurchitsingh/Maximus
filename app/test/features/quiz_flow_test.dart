// S7 done-condition as widget tests: a full quiz on the bundled Roman history
// bank, stored in drift, with the best score on Home.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/app/router.dart';
import 'package:maximus/core/widgets/widgets.dart';
import 'package:maximus/data/models/title.dart';
import 'package:maximus/data/providers.dart';
import 'package:maximus/data/repositories/quiz_repository.dart';
import 'package:maximus/features/quiz/quiz_widgets.dart';

import '../app_harness.dart';
import '../helpers.dart';

const _roman = 'roman-history';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

Future<void> _openQuiz(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  router.push(AppRoute.quiz.location({'titleId': _roman}));
  await AppHarness.settle(tester);
}

Future<TitleDetail> _detail(WidgetTester tester) => AppHarness.run(
  tester,
  () => _container(tester).read(titleDetailProvider(_roman).future),
);

/// The question on screen, found by its prompt.
QuizQuestion _current(WidgetTester tester, TitleDetail d) =>
    d.quiz.firstWhere((q) => find.text(q.prompt).evaluate().isNotEmpty);

/// Answers the visible question, right or wrong, and returns it.
Future<QuizQuestion> _answer(
  WidgetTester tester,
  TitleDetail d, {
  required bool right,
}) async {
  final q = _current(tester, d);
  final option = right ? q.correctIndex : (q.correctIndex + 1) % 4;
  await _tap(tester, find.widgetWithText(AnswerOption, q.options[option]));
  return q;
}

/// Plays a whole attempt with [rightCount] correct answers.
Future<List<QuizQuestion>> _play(
  WidgetTester tester,
  TitleDetail d, {
  required int rightCount,
}) async {
  final shown = <QuizQuestion>[];
  for (var i = 0; i < 6; i++) {
    expect(find.text('${i + 1} of 6'), findsOneWidget);
    shown.add(await _answer(tester, d, right: i < rightCount));
    await _tap(tester, find.text(i == 5 ? 'See result' : 'Next'));
  }
  return shown;
}

void main() {
  testWidgets('full run: feedback, result stored, best score on Home', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    expect(find.byType(EmptyScores, skipOffstage: false), findsOneWidget);
    await _openQuiz(tester);
    final d = await _detail(tester);

    // Next stays disabled until the question is answered.
    expect(find.text('1 of 6'), findsOneWidget);
    final next = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(next.onPressed, isNull);

    // Wrong answer: "Not quite", the correct option shows Right, explanation.
    final first = await _answer(tester, d, right: false);
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text(first.explanation), findsOneWidget);

    // Further taps are ignored: the answer cannot change.
    await _tap(
      tester,
      find.widgetWithText(AnswerOption, first.options[first.correctIndex]),
    );
    expect(find.text('Not quite'), findsOneWidget);
    await _tap(tester, find.text('Next'));

    // Questions 2..6, all right: 5 out of 6.
    final shown = [first];
    for (var i = 1; i < 6; i++) {
      expect(find.text('${i + 1} of 6'), findsOneWidget);
      shown.add(await _answer(tester, d, right: true));
      expect(find.text('Right'), findsOneWidget);
      expect(find.text('Not quite'), findsNothing);
      await _tap(tester, find.text(i == 5 ? 'See result' : 'Next'));
    }
    expect(shown.map((q) => q.id).toSet(), hasLength(6));

    expect(find.text('5 out of 6'), findsOneWidget);
    expect(find.text('Ave! Very nicely done.'), findsOneWidget);
    expect(find.byType(QuizReviewRow), findsNWidgets(6));
    expect(find.text('Review lessons you missed'), findsOneWidget);

    final rows = await AppHarness.run(
      tester,
      h.db.select(h.db.quizResults).get,
    );
    expect(rows.single.score, 5);
    expect(rows.single.total, 6);
    expect(rows.single.shownIds, [for (final q in shown) q.id]);
    expect(rows.single.missedIds, [first.id]);
    final seen = await AppHarness.run(tester, h.db.select(h.db.quizSeen).get);
    expect(seen.map((r) => r.questionId).toSet(), {
      for (final q in shown) q.id,
    });

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(EmptyScores), findsNothing);
    expect(find.text('5/6', skipOffstage: false), findsOneWidget);

    await h.dispose(tester);
  });

  testWidgets('review opens the lesson of the first missed question', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await _openQuiz(tester);
    final d = await _detail(tester);
    final shown = await _play(tester, d, rightCount: 3);
    expect(find.text('3 out of 6'), findsOneWidget);
    expect(find.text('Good going. A few to revisit.'), findsOneWidget);

    await _tap(tester, find.text('Review lessons you missed'));
    final lesson = d.lesson(shown[3].lessonId!)!;
    expect(find.text('Lesson ${lesson.index} of 6'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a perfect score has nothing to review; retry picks new ones', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await _openQuiz(tester);
    final d = await _detail(tester);
    final first = await _play(tester, d, rightCount: 6);
    expect(find.text('6 out of 6'), findsOneWidget);
    expect(find.text('Review lessons you missed'), findsNothing);

    await _tap(tester, find.text('Try 6 new questions'));
    expect(find.text('1 of 6'), findsOneWidget);
    // 4 of the 10 are unseen, and they come first.
    final unseen = d.quiz.where((q) => !first.contains(q)).toSet();
    final second = await _play(tester, d, rightCount: 0);
    expect(second.take(4).toSet(), unseen);
    expect(find.text('0 out of 6'), findsOneWidget);
    expect(find.text('A start. The lessons will help.'), findsOneWidget);

    // Home keeps the best attempt.
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.text('6/6', skipOffstage: false), findsOneWidget);
    expect(find.text('0/6', skipOffstage: false), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('leaving mid-way stores no result, answers stay seen', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    await _openQuiz(tester);
    final d = await _detail(tester);
    final q = await _answer(tester, d, right: true);
    await _tap(tester, find.bySemanticsLabel('Back'));

    expect(
      await AppHarness.run(tester, h.db.select(h.db.quizResults).get),
      isEmpty,
    );
    final seen = await AppHarness.run(tester, h.db.select(h.db.quizSeen).get);
    expect(seen.single.questionId, q.id);
    expect(find.byType(EmptyScores, skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a title under 6 questions shows the empty state', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push(AppRoute.quiz.location({'titleId': 'chanakya'}));
    await AppHarness.settle(tester);
    expect(find.text('No quiz yet'), findsOneWidget);
    await h.dispose(tester);
  });
}
