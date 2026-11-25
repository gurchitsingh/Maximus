// Guard for a "drop to Home" report (S27, seen once, not reproduced): the
// first sync pull on a fresh device ends (hydrating true to false), which
// re-runs the router redirect. A signed-in user on a title screen must stay.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/app/app.dart';
import 'package:maximus/app/router.dart';
import 'package:maximus/data/sync/sync_api.dart';
import 'package:maximus/data/sync/sync_providers.dart';

import '../app_harness.dart';
import '../helpers.dart';

/// A sync API whose first pull waits for [gate].
class _GatedSyncApi implements SyncApi {
  final gate = Completer<void>();

  @override
  Future<PullPage> pull(int since, {int limit = SyncLimits.pullLimit}) async {
    await gate.future;
    return const PullPage(records: [], cursor: 1, hasMore: false, reset: false);
  }

  @override
  Future<PushResult> push(records) async =>
      const PushResult(applied: {}, superseded: {}, rejected: {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the first pull ending keeps the user on the chat screen', (
    tester,
  ) async {
    usePixel8(tester);
    final api = _GatedSyncApi();
    await AppHarness.pump(
      tester,
      sync: true,
      overrides: [syncApiProvider.overrideWithValue(api)],
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(MaximusApp)));
    final router = c.read(routerProvider);
    router.push('/sheet/chanakya');
    await AppHarness.settle(tester);
    router.pushReplacement('/title/chanakya/chat');
    await AppHarness.settle(tester);
    expect(c.read(syncStatusProvider).hydrating, isTrue);

    api.gate.complete();
    await AppHarness.settle(tester);

    expect(c.read(syncStatusProvider).hydrating, isFalse);
    expect(router.state.uri.path, '/title/chanakya/chat');
  });
}
