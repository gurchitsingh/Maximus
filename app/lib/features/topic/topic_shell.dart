// Shell for the screens inside a title (CONTRACTS 8.3): topic bar with
// Lessons, Chat and Quiz (DESIGN_SPEC 7.8). The Quiz tab exists only when
// the title serves at least 6 questions (CONTRACTS 7.1).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../placeholder_body.dart';
import '../reader/reader_screen.dart';

enum TopicTab { lessons, chat, quiz }

class TopicShell extends ConsumerWidget {
  const TopicShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleId = state.pathParameters['titleId']!;
    final path = state.uri.path;
    final current = path.contains('/chat')
        ? TopicTab.chat
        : (path.contains('/quiz') ? TopicTab.quiz : TopicTab.lessons);
    final summary = ref.watch(catalogueProvider).value?.title(titleId);
    final hasQuiz = (summary?.quizCount ?? 0) >= 6;
    final tabs = [
      TopicTab.lessons,
      TopicTab.chat,
      if (hasQuiz || current == TopicTab.quiz) TopicTab.quiz,
    ];

    Future<void> select(int i) async {
      final tab = tabs[i];
      if (tab == current) {
        // The active Lessons tab opens the lessons list.
        if (tab == TopicTab.lessons) {
          final d = await ref.read(titleDetailProvider(titleId).future);
          if (context.mounted) {
            showLessonsList(
              context,
              ref,
              d,
              state.pathParameters['lessonId'] ?? '',
            );
          }
        }
        return;
      }
      final router = GoRouter.of(context);
      switch (tab) {
        case TopicTab.lessons:
          final d = await ref.read(titleDetailProvider(titleId).future);
          if (d.lessons.isEmpty) return;
          final l = ref
              .read(titleProgressProvider(titleId))
              .resumeLesson(d.lessons);
          router.pushReplacement(
            AppRoute.reader.location({'titleId': titleId, 'lessonId': l.id}),
          );
        case TopicTab.chat:
          router.pushReplacement(AppRoute.chat.location({'titleId': titleId}));
        case TopicTab.quiz:
          router.pushReplacement(AppRoute.quiz.location({'titleId': titleId}));
      }
    }

    return Scaffold(
      backgroundColor: context.mx.bg,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: MxNavBar(
        items: [for (final t in tabs) MxNavItem.topicTabs[t.index]],
        currentIndex: tabs.indexOf(current),
        onSelected: select,
      ),
    );
  }
}

/// Chat (S15) is not built yet: same header, placeholder body.
class TopicPlaceholder extends ConsumerWidget {
  const TopicPlaceholder({
    super.key,
    required this.titleId,
    required this.subtitle,
    required this.session,
  });

  final String titleId;
  final String subtitle;
  final String session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(catalogueProvider).value?.title(titleId);
    return Column(
      children: [
        MxPushedTopBar(
          kicker: t?.name ?? '',
          kickerColor: t == null
              ? null
              : readableTint(hexColor(t.tint), context.mx.bg),
          title: subtitle,
          onBack: () => context.pop(),
        ),
        Expanded(
          child: PlaceholderBody(title: subtitle, session: session),
        ),
      ],
    );
  }
}
