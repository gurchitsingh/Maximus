// go_router config (CONTRACTS 8.3, 19). S6 adds the title sheet, the reader
// and the topic shell (chat is a placeholder until S15). S7 adds the quiz.
// S18 adds Welcome, the sign-in routes and the auth redirect; onboarding
// arrives in S5.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/gallery/gallery_screen.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/mx_bottom_sheet.dart';
import '../data/db/tables/user_tables.dart' show SettingKeys;
import '../data/providers.dart' show settingsMapProvider;
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_redirect.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/credits/credits_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/quiz/quiz_result_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/title_sheet/title_sheet.dart';
import '../features/topic/topic_shell.dart';
import 'shell.dart';

enum AppRoute {
  splash('/'),
  signIn('/sign-in'),
  signUp('/sign-up'),
  forgotPassword('/forgot-password'),
  verifyEmail('/verify-email'),
  home('/home'),
  library('/library'),
  feed('/feed'),
  settings('/settings'),
  titleSheet('/sheet/:titleId'),
  reader('/title/:titleId/lesson/:lessonId'),
  chat('/title/:titleId/chat'),
  quiz('/title/:titleId/quiz'),
  quizResult('/title/:titleId/quiz/result'),
  credits('/settings/credits'),
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

/// First onboarding step, null until S5 builds onboarding (then
/// `AppRoute.onboardingTheme.path`). While null, sign-in goes to Home.
const String? _onboardingPath = null;

/// [auth] reads the session for the redirect (CONTRACTS 19) and
/// [refreshListenable] re-runs it on changes. Without [auth] the router
/// behaves as signed in (widget tests that build their own router).
GoRouter buildRouter({
  String? initialLocation,
  AuthState Function()? auth,
  bool Function()? onboardingDone,
  Listenable? refreshListenable,
}) {
  // One key per router, so a second app instance (tests) never shares it.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation ?? _startPath() ?? AppRoute.splash.path,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;
      // The Study tab is gone: it is the first section of Library (D40).
      if (path == '/study') return AppRoute.library.path;
      // The gallery is hidden in release and profile builds.
      if (!kDebugMode && path.startsWith('/dev')) return AppRoute.home.path;
      if (auth == null) {
        return path == AppRoute.splash.path ? AppRoute.home.path : null;
      }
      // Signed out: Welcome, then Sign in. Signed in: onboarding or Home.
      return authRedirect(
        path,
        auth(),
        onboardingPath: _onboardingPath,
        onboardingDone: onboardingDone?.call() ?? false,
      );
    },
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        pageBuilder: (_, state) => _fadePage(state, const WelcomeScreen()),
      ),
      for (final (route, screen) in [
        (AppRoute.signIn, const SignInScreen()),
        (AppRoute.signUp, const SignInScreen(mode: AuthMode.signUp)),
        (AppRoute.verifyEmail, const VerifyEmailScreen()),
      ])
        GoRoute(
          path: route.path,
          name: route.name,
          pageBuilder: (_, state) => _fadePage(state, screen),
        ),
      GoRoute(
        path: AppRoute.forgotPassword.path,
        name: AppRoute.forgotPassword.name,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          for (final (route, screen) in [
            (AppRoute.home, const HomeScreen()),
            (AppRoute.library, const LibraryScreen()),
            (AppRoute.feed, const FeedScreen()),
            (AppRoute.settings, const SettingsScreen()),
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
        path: AppRoute.credits.path,
        name: AppRoute.credits.name,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const CreditsScreen(),
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
  // Bumped when the kind of session changes, so the redirect runs again.
  // Not on user-detail updates (GET /v1/me): a refresh re-parses the
  // location and the tab shell can restore the wrong branch.
  final refresh = ValueNotifier<int>(0);
  ref.listen(
    authControllerProvider.select(
      (s) => switch (s) {
        AuthLoading() => 0,
        SignedOut() => 1,
        SignedIn(showVerify: true) => 2,
        SignedIn() => 3,
      },
    ),
    (_, _) => refresh.value++,
  );
  ref.listen(
    settingsMapProvider.select((s) => s.value?[SettingKeys.onboardingDone]),
    (_, _) => refresh.value++,
  );
  final router = buildRouter(
    auth: () => ref.read(authControllerProvider),
    onboardingDone: () =>
        ref.read(settingsMapProvider).value?[SettingKeys.onboardingDone] ==
        'true',
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
