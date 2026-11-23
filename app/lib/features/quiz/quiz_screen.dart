// Quiz question (DESIGN_SPEC 9.3.7 to 9.3.9, CONTRACTS 7.1): one question per
// screen, instant feedback, one answer each, graded on the device. No timer,
// lives or streaks. Leaving mid-way abandons the attempt: no result is
// stored, but answered questions stay seen.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/title.dart';
import '../../data/providers.dart';
import '../../domain/quiz/quiz_picker.dart';
import '../../domain/quiz/quiz_scoring.dart';
import '../shared/title_visuals.dart';
import 'quiz_providers.dart';
import 'quiz_widgets.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.titleId});

  final String titleId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _explanationKey = GlobalKey();
  TitleDetail? _detail;
  List<QuizQuestion> _questions = const [];
  QuizAttempt? _attempt;
  var _index = 0;
  var _failed = false;
  var _saving = false;

  /// Seen marks are written in answer order; "See result" waits for them so
  /// the next pick never reuses a question just answered.
  Future<void> _seenWrites = Future.value();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final d = await ref.read(titleDetailProvider(widget.titleId).future);
      if (!mounted) return;
      if (d.quiz.length < quizLength) {
        setState(() => _detail = d);
        return;
      }
      final questions = await ref
          .read(quizRepositoryProvider)
          .startAttempt(d, ref.read(quizRandomProvider));
      if (!mounted) return;
      setState(() {
        _detail = d;
        _questions = questions;
        _attempt = QuizAttempt(
          questionIds: [for (final q in questions) q.id],
          correctIndexes: [for (final q in questions) q.correctIndex],
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    ref.invalidate(titleDetailProvider(widget.titleId));
    _start();
  }

  void _answer(int option) {
    if (!_attempt!.answer(_index, option)) return;
    final question = _questions[_index];
    final repo = ref.read(quizRepositoryProvider);
    // A lost seen mark only means this question may come up again.
    _seenWrites = _seenWrites
        .then((_) => repo.markSeen(question))
        .catchError((Object _) {});
    setState(() {});
    // The explanation can land below the fold at large font sizes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _explanationKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: MxMotion.reduced(target)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _seenWrites;
      final id = await ref
          .read(quizRepositoryProvider)
          .saveResult(
            titleId: widget.titleId,
            attempt: _attempt!,
            contentVersion: _detail!.summary.contentVersion,
          );
      if (!mounted) return;
      final path = AppRoute.quizResult.location({'titleId': widget.titleId});
      router.pushReplacement('$path?attempt=$id');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your score. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuizTopBar(titleId: widget.titleId),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_failed) {
      return Center(
        child: ErrorState(
          title: 'Not available offline',
          body: 'This title needs a connection the first time.',
          offline: true,
          onRetry: _retry,
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: TextSkeleton(lines: 6),
      );
    }
    final attempt = _attempt;
    if (attempt == null) {
      return Center(
        child: EmptyState(
          art: TitleArt(data: titleArt(detail.summary, detail.image)),
          title: 'No quiz yet',
          body: 'This title does not have enough questions yet.',
          actionLabel: 'Go back',
          onAction: () => context.pop(),
        ),
      );
    }
    return _question(context, attempt);
  }

  Widget _question(BuildContext context, QuizAttempt attempt) {
    final c = context.mx;
    final q = _questions[_index];
    final picked = attempt.answerAt(_index);
    final answered = picked != null;
    final isLast = _index == _questions.length - 1;
    final filled = (_index + (answered ? 1 : 0)) / _questions.length;

    AnswerState stateOf(int option) {
      if (!answered) return AnswerState.idle;
      if (option == q.correctIndex) return AnswerState.right;
      return option == picked ? AnswerState.wrong : AnswerState.idle;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // A fresh scroll position for every question.
            key: ValueKey(q.id),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: MxProgressBar(value: filled, quiz: true)),
                    const SizedBox(width: 12),
                    Text(
                      '${_index + 1} of ${_questions.length}',
                      style: MxText.buttonS.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    q.prompt,
                    style: MxText.question.copyWith(color: c.text),
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < q.options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  AnswerMotion(
                    key: ValueKey('${q.id}:$i'),
                    state: stateOf(i),
                    picked: picked == i,
                    child: AnswerOption(
                      label: q.options[i],
                      state: stateOf(i),
                      onPressed: answered ? null : () => _answer(i),
                    ),
                  ),
                ],
                if (answered) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: ExplanationBox(q.explanation, key: _explanationKey),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PrimaryButton(
            label: isLast ? 'See result' : 'Next',
            onPressed: answered && !_saving ? _next : null,
          ),
        ),
      ],
    );
  }
}
