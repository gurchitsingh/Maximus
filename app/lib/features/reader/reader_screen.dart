// Lesson reader (DESIGN_SPEC 9.3.1, 9.3.2, 7.22, 7.21; FLOW 6). The topic
// bar comes from TopicShell. Previous/next swap the page in place so Back
// returns to where the topic was opened from.
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
import '../../domain/markdown_lite.dart';
import '../shared/title_visuals.dart';
import 'lesson_body.dart';
import 'read_aloud.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.titleId,
    required this.lessonId,
  });

  final String titleId;
  final String lessonId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  // Read in initState, not lazily: dispose must never touch ref.
  late final ReadAloudController _tts;
  String? _opened;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(readAloudProvider.notifier);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _markOpened(Lesson lesson) {
    if (_opened == lesson.id) return;
    _opened = lesson.id;
    // After the frame: never write to the database during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(userStateRepositoryProvider).openLesson(lesson);
    });
  }

  void _goTo(Lesson l) {
    _tts.stop();
    context.pushReplacement(
      AppRoute.reader.location({'titleId': l.titleId, 'lessonId': l.id}),
    );
  }

  Future<void> _next(TitleDetail d, Lesson lesson) async {
    await _tts.stop();
    final repo = ref.read(userStateRepositoryProvider);
    await repo.completeLesson(lesson);
    if (!mounted) return;
    final i = d.lessons.indexWhere((l) => l.id == lesson.id);
    if (i >= 0 && i < d.lessons.length - 1) {
      _goTo(d.lessons[i + 1]);
      return;
    }
    // Last lesson: celebrate when every lesson is done (FLOW 6). Read drift
    // directly: Riverpod pauses providers whose listeners are off screen.
    final done = await ref
        .read(databaseProvider)
        .userStateDao
        .completedLessonIds(d.id);
    if (!mounted) return;
    final left = d.lessons.where((l) => !done.contains(l.id)).toList();
    if (left.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            left.length == 1
                ? 'Lesson done. One lesson is still unread.'
                : 'Lesson done. ${left.length} lessons are still unread.',
          ),
          action: SnackBarAction(
            label: 'Open it',
            onPressed: () => _goTo(left.first),
          ),
        ),
      );
      return;
    }
    final offerQuiz = d.summary.quizCount >= 6; // CONTRACTS 7.1
    final n = d.lessons.length;
    final quiz = await showCelebration(
      context: context,
      title: 'Topic finished',
      body:
          'You read all $n ${n == 1 ? 'lesson' : 'lessons'} of ${d.summary.name}.'
          '${offerQuiz ? ' Ready for a quick quiz?' : ''}',
      tint: hexColor(d.summary.tint),
      offerQuiz: offerQuiz,
    );
    if (quiz == true && mounted) {
      context.pushReplacement(AppRoute.quiz.location({'titleId': d.id}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(titleDetailProvider(widget.titleId));
    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: TextSkeleton(lines: 8),
      ),
      error: (_, _) => Column(
        children: [
          const MxPushedTopBar(title: 'Lesson'),
          Expanded(
            child: ErrorState(
              title: 'Not available offline',
              body: 'This title needs a connection the first time.',
              offline: true,
              onRetry: () =>
                  ref.invalidate(titleDetailProvider(widget.titleId)),
            ),
          ),
        ],
      ),
      data: (d) {
        if (d.lessons.isEmpty) {
          return const EmptyState(
            title: 'No lessons yet',
            body: 'This title has no lessons yet.',
          );
        }
        final lesson = d.lesson(widget.lessonId) ?? d.lessons.first;
        _markOpened(lesson);
        return _ReaderBody(
          detail: d,
          lesson: lesson,
          onPrevious: lesson.index > 1
              ? () => _goTo(d.lessons[d.lessons.indexOf(lesson) - 1])
              : null,
          onNext: () => _next(d, lesson),
        );
      },
    );
  }
}

class _ReaderBody extends ConsumerWidget {
  const _ReaderBody({
    required this.detail,
    required this.lesson,
    required this.onPrevious,
    required this.onNext,
  });

  final TitleDetail detail;
  final Lesson lesson;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final t = detail.summary;
    final tint = hexColor(t.tint);
    final n = detail.lessons.length;
    final isLast = lesson.index >= detail.lessons.last.index;

    final settings = ref.watch(settingsMapProvider).value ?? const {};
    final speed = double.tryParse(settings['voice_speed'] ?? '') ?? 1.0;
    final playing = ref.watch(readAloudProvider) == lesson.id;
    final spoken =
        lesson.readAloudText ?? plainText(parseMarkdownLite(lesson.body));
    // Speaking is slower than reading: about 150 words a minute at 1x.
    final words = spoken.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final minutes = (words.length / (150 * speed)).ceil().clamp(1, 999);
    final speedLabel = speed == 1.0 ? '1x' : '${speed}x';

    final hero = detail.image(
      lesson.imageIds.isEmpty ? null : lesson.imageIds.first,
    );

    return Column(
      children: [
        MxPushedTopBar(
          kicker: t.name,
          // Tint as text must stay readable on paper themes (11.9).
          kickerColor: readableTint(tint, c.bg),
          title: 'Lesson ${lesson.index} of $n',
          onBack: () => context.pop(),
          trailing: MxIconButton(
            icon: MxIcons.book,
            label: 'All lessons',
            onPressed: () => showLessonsList(context, ref, detail, lesson.id),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: LessonSegments(count: n, current: lesson.index, tint: tint),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey(lesson.id),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hero != null)
                  LessonImage(detail: detail, image: hero, height: 210)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MxRadius.card),
                    child: SizedBox(
                      height: 210,
                      child: TitleArt(data: titleArt(t, detail.image)),
                    ),
                  ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    lesson.heading,
                    style: MxText.lessonTitle.copyWith(color: c.text),
                  ),
                ),
                const SizedBox(height: 14),
                LessonBody(detail: detail, lesson: lesson),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        ReadAloudBar(
          playing: playing,
          meta: 'About $minutes min · $speedLabel speed',
          isLast: isLast,
          onPlayPause: () => ref
              .read(readAloudProvider.notifier)
              .toggle(
                lessonId: lesson.id,
                text: '${lesson.heading}.\n$spoken',
                speed: speed,
                voiceName: settings['voice_name'],
              ),
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

/// Lessons list sheet (DESIGN_SPEC 11.7 default): every lesson with its
/// state; tap opens it.
Future<void> showLessonsList(
  BuildContext context,
  WidgetRef ref,
  TitleDetail detail,
  String currentId,
) {
  final router = GoRouter.of(context);
  return showMxBottomSheet<void>(
    context: context,
    // The sheet watches progress itself: it is on screen, so never paused.
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final c = ctx.mx;
        final rows =
            ref.watch(progressProvider).value ?? const <LessonProgressRow>[];
        final done = {
          for (final r in rows)
            if (r.titleId == detail.id && r.completedAt != null) r.lessonId,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              detail.summary.name,
              style: MxText.emptyTitle.copyWith(color: c.text),
            ),
            const SizedBox(height: 4),
            Text(
              '${done.length} of ${detail.lessons.length} read',
              style: MxText.sub.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 12),
            for (final l in detail.lessons)
              _LessonRow(
                lesson: l,
                done: done.contains(l.id),
                current: l.id == currentId,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (l.id != currentId) {
                    router.pushReplacement(
                      AppRoute.reader.location({
                        'titleId': l.titleId,
                        'lessonId': l.id,
                      }),
                    );
                  }
                },
              ),
          ],
        );
      },
    ),
  );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final Lesson lesson;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final state = done ? 'read' : (current ? 'open now' : 'not read');
    return Semantics(
      button: true,
      selected: current,
      label: 'Lesson ${lesson.index}: ${lesson.heading}, $state',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MxRadius.thumb),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? c.accent : null,
                  border: Border.all(
                    color: current ? c.accentText : c.divider,
                    width: 2,
                  ),
                ),
                child: done
                    ? MxIcon(MxIcons.check, size: 16, color: c.onAccent)
                    : Text(
                        '${lesson.index}',
                        style: MxText.meta.copyWith(color: c.text),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  lesson.heading,
                  style: MxText.rowTitle.copyWith(
                    color: current ? c.accentText : c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${lesson.readingMinutes} min',
                style: MxText.sub.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
