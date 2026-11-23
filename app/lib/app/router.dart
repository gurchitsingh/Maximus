// go_router config (CONTRACTS 8.3). S6 adds the title sheet, the reader and
// the topic shell (chat is a placeholder until S15). S7 adds the quiz.
// Onboarding and splash arrive in S5.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/gallery/gallery_screen.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/mx_bottom_sheet.dart';
import '../features/feed/feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/quiz/quiz_result_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/study/study_screen.dart';
import '../features/title_sheet/title_sheet.dart';
import '../features/topic/topic_shell.dart';
import 'shell.dart';

enum AppRoute {
  splash('/'),
  home('/home'),
  library('/library'),
  feed('/feed'),
  study('/study'),
  titleSheet('/sheet/:titleId'),
  reader('/title/:titleId/lesson/:lessonId'),
  chat('/title/:titleId/chat'),
  quiz('/title/:titleId/quiz'),
  quizResult('/title/:titleId/quiz/result'),
  settings('/settings'),
  gallery('/dev/gallery');

  const AppRoute(this.path);
  final String path;

  /// The path with `:name` segments filled in (URI-encoded).
  String location([Map<String, String> params = const {}]) =>
      path.replaceAllMapped(
        RegExp(r':(\w+)'),
        (m) => Uri.encodeComponent(
          params[m.group(1)] ??
              (throw ArgumentError(
                'missing route param ${m.group(1)} for $name',
              )),
        ),
      );
}

/// Debug-only start route by name, e.g.
/// `flutter run --dart-define=MX_START=gallery`. A name, not a path, because
/// Git Bash rewrites '/dev/...' arguments into Windows paths.
const _startOverride = String.fromEnvironment('MX_START');

String? _startPath() {
  if (!kDebugMode || _startOverride.isEmpty) return null;
  for (final r in AppRoute.values) {
    if (r.name == _startOverride) return r.path;
  }
  return null;
}

/// Lesson pages fade into each other (previous/next swap in place).
Page<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: MxMotion.fade,
  reverseTransitionDuration: MxMotion.fade,
  transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
);

GoRouter buildRouter({String? initialLocation}) {
  // One key per router, so a second app instance (tests) never shares it.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation ?? _startPath() ?? AppRoute.home.path,
    redirect: (context, state) {
      final path = state.uri.path;
      // Splash and onboarding are S5; until then '/' goes straight to Home.
      if (path == AppRoute.splash.path) return AppRoute.home.path;
      // The gallery is hidden in release and profile builds.
      if (!kDebugMode && path.startsWith('/dev')) return AppRoute.home.path;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          for (final (route, screen) in [
            (AppRoute.home, const HomeScreen()),
            (AppRoute.library, const LibraryScreen()),
            (AppRoute.feed, const FeedScreen()),
            (AppRoute.study, const StudyScreen()),
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: route.path,
                  name: route.name,
                  builder: (_, _) => screen,
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: AppRoute.titleSheet.path,
        name: AppRoute.titleSheet.name,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) {
          final id = state.pathParameters['titleId']!;
          return MxSheetPage<void>(
            key: state.pageKey,
            banner: TitleSheetBanner(titleId: id),
            builder: (_) => TitleSheet(titleId: id),
          );
        },
      ),
      ShellRoute(
        parentNavigatorKey: rootKey,
        builder: (_, state, child) => TopicShell(state: state, child: child),
        routes: [
          GoRoute(
            path: AppRoute.reader.path,
            name: AppRoute.reader.name,
            pageBuilder: (_, state) => _fadePage(
              state,
              ReaderScreen(
                key: ValueKey(state.pathParameters['lessonId']),
                titleId: state.pathParameters['titleId']!,
                lessonId: state.pathParameters['lessonId']!,
              ),
            ),
          ),
          GoRoute(
            path: AppRoute.chat.path,
            name: AppRoute.chat.name,
            pageBuilder: (_, state) => _fadePage(
              state,
              TopicPlaceholder(
                titleId: state.pathParameters['titleId']!,
                subtitle: 'Ask a question',
                session: 'S15',
              ),
            ),
          ),
          GoRoute(
            path: AppRoute.quiz.path,
            name: AppRoute.quiz.name,
            pageBuilder: (_, state) => _fadePage(
              state,
              QuizScreen(titleId: state.pathParameters['titleId']!),
            ),
          ),
          GoRoute(
            path: AppRoute.quizResult.path,
            name: AppRoute.quizResult.name,
            pageBuilder: (_, state) => _fadePage(
              state,
              QuizResultScreen(
                titleId: state.pathParameters['titleId']!,
                attemptId: int.tryParse(
                  state.uri.queryParameters['attempt'] ?? '',
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.gallery.path,
        name: AppRoute.gallery.name,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const GalleryScreen(),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
