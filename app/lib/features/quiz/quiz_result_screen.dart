// Quiz result (DESIGN_SPEC 9.3.10, CONTRACTS 7.1). Reads the stored attempt,
// so it shows the same thing however it was reached.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart';
import '../../data/models/title.dart';
import '../../data/providers.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../domain/quiz/quiz_scoring.dart';
import '../reader/reader_screen.dart';
import '../shared/title_visuals.dart';
import 'quiz_providers.dart';
import 'quiz_widgets.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({super.key, required this.titleId, this.attemptId});

  final String titleId;

  /// Null shows the title's latest attempt.
  final int? attemptId;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  late Future<(TitleDetail, QuizResultRow?)> _data = _load();

  Future<(TitleDetail, QuizResultRow?)> _load() async {
    final repo = ref.read(quizRepositoryProvider);
    final detail = await ref.read(titleDetailProvider(widget.titleId).future);
    return (detail, await repo.result(widget.titleId, widget.attemptId));
  }

  void _tryAgain() => context.pushReplacement(
    AppRoute.quiz.location({'titleId': widget.titleId}),
  );

  /// The Reader at the first missed question that names a lesson still in
  /// the title; the Lessons list when none does.
  void _review(TitleDetail d, QuizResultRow r) {
    final byId = {for (final q in d.quiz) q.id: q};
    for (final id in r.missedIds) {
      final lessonId = byId[id]?.lessonId;
      if (lessonId != null && d.lesson(lessonId) != null) {
        context.pushReplacement(
          AppRoute.reader.location({'titleId': d.id, 'lessonId': lessonId}),
        );
        return;
      }
    }
    showLessonsList(context, ref, d, '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuizTopBar(titleId: widget.titleId),
        Expanded(
          child: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: ErrorState(
                    onRetry: () => setState(() => _data = _load()),
                  ),
                );
              }
              final data = snap.data;
              if (data == null) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: TextSkeleton(lines: 6),
                );
              }
              final (detail, row) = data;
              if (row == null) {
                return Center(
                  child: EmptyState(
                    art: TitleArt(data: titleArt(detail.summary, detail.image)),
                    title: 'No result yet',
                    body: 'Take the quiz and your score lands here.',
                    actionLabel: 'Take the quiz',
                    onAction: _tryAgain,
                  ),
                );
              }
              return _result(context, detail, row);
            },
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, TitleDetail d, QuizResultRow r) {
    final c = context.mx;
    final byId = {for (final q in d.quiz) q.id: q};
    final missed = r.missedIds.toSet();
    // A question removed by a content update drops out of the list; the
    // stored score stays.
    final shown = [
      for (final id in r.shownIds)
        if (byId[id] != null) byId[id]!,
    ];
    // Only on arrival from "See result", so reopening a result never replays
    // it. Reduced motion skips it.
    final celebrate =
        widget.attemptId != null &&
        celebratesQuizScore(r.score) &&
        !MxMotion.reduced(context);
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              '${r.score} out of ${r.total}',
              style: MxText.scoreXL.copyWith(color: c.accentText),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            quizResultMessage(r.score),
            style: MxText.readerHeading.copyWith(color: c.text),
          ),
          const SizedBox(height: 16),
          for (final q in shown) ...[
            QuizReviewRow(question: q, missed: missed.contains(q.id)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          PrimaryButton(label: 'Try 6 new questions', onPressed: _tryAgain),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Review lessons you missed',
              onPressed: () => _review(d, r),
            ),
          ],
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (celebrate)
          IgnorePointer(child: Confetti(extra: hexColor(d.summary.tint))),
      ],
    );
  }
}
