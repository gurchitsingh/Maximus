// go_router config (CONTRACTS 8.3). S4 registers the four tabs, Settings and
// the debug gallery; onboarding, sheet and topic routes arrive in S5 to S7.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/gallery/gallery_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/study/study_screen.dart';
import 'shell.dart';

enum AppRoute {
  splash('/'),
  home('/home'),
  library('/library'),
  feed('/feed'),
  study('/study'),
  settings('/settings'),
  gallery('/dev/gallery');

  const AppRoute(this.path);
  final String path;
}

/// Debug-only start location, e.g.
/// `flutter run --dart-define=MX_START=/dev/gallery`.
const _startOverride = String.fromEnvironment('MX_START');

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({String? initialLocation}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation:
      initialLocation ??
      (kDebugMode && _startOverride.isNotEmpty
          ? _startOverride
          : AppRoute.home.path),
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
      path: AppRoute.settings.path,
      name: AppRoute.settings.name,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoute.gallery.path,
      name: AppRoute.gallery.name,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const GalleryScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
