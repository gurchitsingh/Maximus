// Offline-first sync (CONTRACTS 15.5, D38). Push dirty rows, then pull
// from the stored cursor. One run at a time. Failures are silent: the app
// keeps working on drift, rows stay dirty and a later trigger retries.
import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../api/api_error.dart';
import '../db/app_database.dart';
import 'sync_api.dart';
import 'sync_dao.dart';
import 'sync_record.dart';

/// Why a run was asked for. Some triggers wait out a backoff; the ones the
/// user or the network caused run at once.
enum SyncTrigger {
  signIn,
  appStart,
  resume,
  online,
  localWrite,
  periodic,
  manual,
  retry;

  bool get bypassesBackoff =>
      this == signIn || this == online || this == manual || this == appStart;
}

enum SyncResult {
  /// Pushed and pulled.
  ok,

  /// No network or the server is down: silent, retried later.
  offline,

  /// The server answered with an error (5xx, 429, a bad body): retried
  /// later with backoff.
  failed,

  /// 401 after the interceptor's one refresh: the session is over (the
  /// auth controller routes to Sign in, data kept). Not retried.
  unauthorized,

  /// Not signed in, stopped, or skipped by the backoff.
  skipped,
}

@immutable
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.hydrating = false,
    this.last = SyncResult.skipped,
  });

  final bool running;

  /// The first pull after sign-in on a device with no cursor yet (fresh
  /// device): onboarding waits for it (14.5).
  final bool hydrating;

  /// Outcome of the last finished run.
  final SyncResult last;

  SyncStatus copyWith({bool? running, bool? hydrating, SyncResult? last}) =>
      SyncStatus(
        running: running ?? this.running,
        hydrating: hydrating ?? this.hydrating,
        last: last ?? this.last,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.running == running &&
      other.hydrating == hydrating &&
      other.last == last;

  @override
  int get hashCode => Object.hash(running, hydrating, last);
}

class SyncService {
  SyncService({
    required this.db,
    required this.api,
    required this.userId,
    this.onSettingsPulled,
    this.debounce = const Duration(seconds: 5),
    this.periodic = const Duration(minutes: 15),
    this.backoff = const [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ],
  });

  final AppDatabase db;
  final SyncApi api;

  /// The signed-in user's id (secure storage), null when signed out.
  final Future<String?> Function() userId;

  /// Called with the stored settings after a pull changed any of them, so
  /// in-memory state (theme, text size) can follow.
  final void Function(Map<String, String> settings)? onSettingsPulled;

  final Duration debounce;
  final Duration periodic;

  /// Waits after the 1st, 2nd, 3rd... failure in a row; the last one is
  /// the cap (15.5: 30 s, 2 min, 10 min).
  final List<Duration> backoff;

  final status = ValueNotifier(const SyncStatus());

  SyncDao get _dao => db.syncDao;

  bool _active = false;
  int _epoch = 0;
  Future<SyncResult>? _current;
  bool _again = false;
  int _failures = 0;
  DateTime? _blockedUntil;
  Timer? _debounceTimer, _retryTimer, _periodicTimer;
  StreamSubscription<Set<TableUpdate>>? _writes;

  bool get active => _active;

  /// Consecutive failed runs (for tests and the backoff).
  int get failures => _failures;

  /// When the next retry is due, if a backoff is running.
  DateTime? get retryAt => _blockedUntil;

  // ---- lifecycle ----

  /// Signed in: watch local writes, run every [periodic], and sync now.
  void start({SyncTrigger trigger = SyncTrigger.signIn}) {
    if (_active) {
      unawaited(sync(trigger));
      return;
    }
    _active = true;
    _failures = 0;
    _blockedUntil = null;
    _writes = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.settings,
            db.interests,
            db.studyList,
            db.ratings,
            db.lessonProgress,
            db.quizResults,
            db.feedState,
          ]),
        )
        .listen((_) => onLocalWrite());
    _periodicTimer = Timer.periodic(
      periodic,
      (_) => unawaited(sync(SyncTrigger.periodic)),
    );
    unawaited(sync(trigger));
  }

  /// Signed out or about to wipe: no new runs, and a run in flight stops
  /// writing (its results are dropped). Completes when that run has ended.
  Future<void> stop() async {
    _active = false;
    _epoch++;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer = _retryTimer = _periodicTimer = null;
    // Not awaited: drift completes a table-update cancel lazily, and no
    // event arrives once it is requested.
    unawaited(_writes?.cancel());
    _writes = null;
    _again = false;
    final running = _current;
    if (running != null) {
      try {
        await running;
      } on Object {
        // Already reported as a result.
      }
    }
    _setStatus(const SyncStatus());
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    unawaited(stop());
    status.dispose();
  }

  void _setStatus(SyncStatus s) {
    if (!_disposed) status.value = s;
  }

  // ---- triggers ----

  void onResume() => unawaited(sync(SyncTrigger.resume));

  void onOnline() => unawaited(sync(SyncTrigger.online));

  /// A drift write to a synced table: sync [debounce] after the last one,
  /// if anything is dirty (the sync's own clean writes are not).
  void onLocalWrite() {
    if (!_active) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      _debounceTimer = null;
      if (!_active) return;
      if (await _dao.dirtyCount() > 0) {
        unawaited(sync(SyncTrigger.localWrite));
      }
    });
  }

  /// "Sync now" in Settings.
  Future<SyncResult> syncNow() => sync(SyncTrigger.manual);

  /// Before sign-out (S15): push and pull once, even if the service was
  /// never started, waiting for a run in flight first. Never wipes.
  Future<SyncResult> flush() async {
    if (_active) {
      await _current;
      return sync(SyncTrigger.manual);
    }
    final running = _current;
    if (running != null) await running;
    final run = _guarded();
    _current = run;
    try {
      return await run;
    } finally {
      if (identical(_current, run)) _current = null;
    }
  }

  /// Runs a sync, or joins the one in flight (single-flight). A request
  /// that arrives during a run makes one more run after it, so a change
  /// made mid-run is never left behind.
  Future<SyncResult> sync(SyncTrigger trigger) {
    if (!_active) return Future.value(SyncResult.skipped);
    final running = _current;
    if (running != null) {
      _again = true;
      return running;
    }
    final until = _blockedUntil;
    if (!trigger.bypassesBackoff &&
        trigger != SyncTrigger.retry &&
        until != null &&
        db.clock().isBefore(until)) {
      return Future.value(SyncResult.skipped);
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    final run = _loop();
    _current = run;
    run.whenComplete(() {
      if (identical(_current, run)) _current = null;
    }).ignore();
    return run;
  }

  Future<SyncResult> _loop() async {
    SyncResult r;
    do {
      _again = false;
      r = await _guarded();
    } while (_again && r == SyncResult.ok && _active);
    return r;
  }

  Future<SyncResult> _guarded() async {
    final epoch = _epoch;
    _setStatus(status.value.copyWith(running: true));
    SyncResult r;
    try {
      r = await _runOnce(epoch);
    } on ApiException catch (e) {
      r = e.status == 401
          ? SyncResult.unauthorized
          : e.isOffline
          ? SyncResult.offline
          : SyncResult.failed;
    } on Object catch (e, st) {
      // A local bug must not break the app: report in debug, retry later.
      debugPrint('sync failed: $e\n$st');
      r = SyncResult.failed;
    }
    if (epoch != _epoch) return SyncResult.skipped;
    _afterRun(r);
    _setStatus(SyncStatus(last: r));
    return r;
  }

  void _afterRun(SyncResult r) {
    switch (r) {
      case SyncResult.ok:
        _failures = 0;
        _blockedUntil = null;
      case SyncResult.offline || SyncResult.failed:
        final wait = backoff[_failures.clamp(0, backoff.length - 1)];
        _failures++;
        _blockedUntil = db.clock().add(wait);
        _retryTimer?.cancel();
        if (!_active) break;
        _retryTimer = Timer(wait, () {
          _retryTimer = null;
          unawaited(sync(SyncTrigger.retry));
        });
      case SyncResult.unauthorized:
        // The interceptor already refreshed once; the auth controller
        // signs out (keeping drift data) when the refresh was refused.
        _failures = 0;
        _blockedUntil = null;
      case SyncResult.skipped:
        break;
    }
  }

  // ---- one run ----

  Future<SyncResult> _runOnce(int epoch) async {
    bool alive() => epoch == _epoch;
    final uid = await userId();
    if (uid == null || !alive()) return SyncResult.skipped;

    // A different account on this phone (the last session ended without a
    // wipe, e.g. a refused refresh): its rows must not reach this account.
    final owner = await _dao.stateValue(SyncStateKeys.userId);
    if (owner != uid) {
      if (owner != null) await db.wipeUserData();
      await _dao.setStateValue(SyncStateKeys.userId, uid);
    }
    final cursor0 = await _dao.cursor();
    // Never synced on this device for this account: the first pull fills
    // it (fresh device, 14.5). Stays true until a run succeeds.
    final hydrating =
        await _dao.stateValue(SyncStateKeys.lastSyncAt) == null;
    if (hydrating) _setStatus(status.value.copyWith(hydrating: true));

    // 1. Push every dirty row, 200 at a time.
    final dirty = await _dao.dirtyRecords();
    for (var i = 0; i < dirty.length; i += SyncLimits.pushBatch) {
      final batch = dirty.sublist(
        i,
        (i + SyncLimits.pushBatch).clamp(0, dirty.length),
      );
      final res = await api.push(batch);
      if (!alive()) return SyncResult.skipped;
      for (final r in batch) {
        final stored = res.superseded[r.key];
        if (res.applied.contains(r.key)) {
          await _dao.ackApplied(r);
        } else if (stored != null) {
          await _dao.applySuperseded(r, stored);
        } else if (res.rejected.containsKey(r.key)) {
          debugPrint('sync: ${r.kind}/${r.id} rejected: ${res.rejected[r.key]}');
          await _dao.dropRejected(r);
        }
        // Not mentioned at all: stays dirty, retried next run.
      }
    }

    // 2. Pull from the cursor until has_more is false.
    var cursor = cursor0;
    var settingsChanged = false;
    var resets = 0;
    while (true) {
      final page = await api.pull(cursor);
      if (!alive()) return SyncResult.skipped;
      if (page.reset) {
        if (++resets > 1) break; // the server keeps asking: try next run
        cursor = 0;
        await _dao.setCursor(0);
        continue;
      }
      await db.transaction(() async {
        for (final r in page.records) {
          try {
            if (await _dao.applyPulled(r) && r.kind == SyncKind.setting) {
              settingsChanged = true;
            }
          } on FormatException catch (e) {
            debugPrint('sync: skipped ${r.kind}/${r.id}: $e');
          } on TypeError catch (e) {
            debugPrint('sync: skipped ${r.kind}/${r.id}: $e');
          }
        }
        await _dao.setCursor(page.cursor);
      });
      cursor = page.cursor;
      if (!page.hasMore) break;
    }
    if (!alive()) return SyncResult.skipped;

    // 3. A fresh device whose account already has onboarding picks skips
    // onboarding, even if the setting itself was never synced.
    if (hydrating) {
      final picks = await db.select(db.interests).get();
      final done = await db.settingsDao.read(SettingKeys.onboardingDone);
      if (done != 'true' && picks.any((p) => !p.deleted)) {
        await db.settingsDao.write(SettingKeys.onboardingDone, 'true');
        settingsChanged = true;
      }
    }

    await _dao.setStateValue(
      SyncStateKeys.lastSyncAt,
      zTime(db.clock()),
    );
    if (settingsChanged) {
      onSettingsPulled?.call(await db.settingsDao.readAll());
    }
    return SyncResult.ok;
  }
}
