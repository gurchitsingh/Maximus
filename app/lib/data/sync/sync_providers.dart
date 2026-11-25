// Riverpod wiring for sync (CONTRACTS 15.5): the service starts when the
// session is signed in and stops when it ends ([syncAuthBridgeProvider]),
// and runs on app resume, when the network comes back, after local writes
// and every 15 minutes.
//
// The service does not depend on the auth controller (the controller stops
// it before wiping), so the auth link lives in its own provider.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_models.dart';
import '../api/auth_tokens.dart';
import '../providers.dart';
import 'sync_api.dart';
import 'sync_dao.dart';
import 'sync_service.dart';

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(ref.watch(apiClientProvider)),
);

/// True when the device has a network, false when it has none. Errors
/// (no plugin in tests, odd platforms) are swallowed: sync then relies on
/// its other triggers.
final connectivityProvider = Provider<Stream<bool>>(
  (_) => Connectivity().onConnectivityChanged
      .map(
        (r) => r.isNotEmpty && r.any((c) => c != ConnectivityResult.none),
      )
      .handleError((Object _) {}),
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(databaseProvider),
    api: ref.watch(syncApiProvider),
    userId: () => ref.read(tokenStoreProvider).read(TokenKeys.userId),
    onSettingsPulled: (s) => ref
        .read(themeSettingsProvider.notifier)
        .restore(ThemeSettings.fromStored(s)),
  );

  final lifecycle = AppLifecycleListener(onResume: service.onResume);

  bool? online;
  final net = ref.watch(connectivityProvider).listen((now) {
    if (online == false && now) service.onOnline();
    online = now;
  });

  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(net.cancel());
    service.dispose();
  });
  return service;
});

/// Starts sync on sign-in (and on a cold start that finds a session) and
/// stops it on sign-out. The router keeps it alive.
final syncAuthBridgeProvider = Provider<void>((ref) {
  final service = ref.watch(syncServiceProvider);
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    switch (next) {
      case SignedIn():
        service.start(
          trigger: prev is AuthLoading || prev == null
              ? SyncTrigger.appStart
              : SyncTrigger.signIn,
        );
      case SignedOut():
        unawaited(service.stop());
      case AuthLoading():
        break;
    }
  }, fireImmediately: true);
});

/// Running, hydrating and the last result, for Settings and the router.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final n = ref.watch(syncServiceProvider).status;
  void changed() => ref.invalidateSelf();
  n.addListener(changed);
  ref.onDispose(() => n.removeListener(changed));
  return n.value;
});

/// When the last sync finished, null if never (Settings "Last synced").
final lastSyncedAtProvider = StreamProvider<DateTime?>(
  (ref) => ref
      .watch(databaseProvider)
      .syncDao
      .watchStateValue(SyncStateKeys.lastSyncAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)?.toUtc()),
);

/// Local changes the server has not acknowledged (sign-out warning).
Future<int> unsyncedChanges(WidgetRef ref) =>
    ref.read(databaseProvider).syncDao.dirtyCount();
