// Drift side of sync (CONTRACTS 15.1, 15.5): turns dirty rows into wire
// records, applies server records by last-write-wins, clears `dirty` only
// for what the server acknowledged, and keeps the sync_state keys.
import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'sync_record.dart';

part 'sync_dao.g.dart';

/// sync_state keys (15.5).
abstract final class SyncStateKeys {
  static const cursor = 'cursor';
  static const lastSyncAt = 'last_sync_at';
  static const userId = 'user_id';
}

/// A local row's sync columns.
typedef LocalStamp = ({DateTime updatedAt, bool deleted, bool dirty});

@DriftAccessor(
  tables: [
    Settings,
    Interests,
    StudyList,
    Ratings,
    LessonProgress,
    QuizResults,
    FeedState,
    SyncState,
  ],
)
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ---- sync_state ----

  Future<String?> stateValue(String key) async => (await (select(
    syncState,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Stream<String?> watchStateValue(String key) =>
      (select(syncState)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((r) => r?.value);

  Future<void> setStateValue(String key, String? value) => value == null
      ? (delete(syncState)..where((t) => t.key.equals(key))).go()
      : into(syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(key: key, value: value),
        );

  Future<int> cursor() async =>
      int.tryParse(await stateValue(SyncStateKeys.cursor) ?? '') ?? 0;

  Future<void> setCursor(int c) =>
      setStateValue(SyncStateKeys.cursor, c.toString());

  // ---- outgoing ----

  /// Number of local changes the server has not acknowledged.
  Future<int> dirtyCount() async {
    var n = 0;
    Future<int> count<T extends HasResultSet, R>(
      ResultSetImplementation<T, R> t,
      Expression<bool> where,
    ) async {
      final c = countAll();
      final q = selectOnly(t)
        ..addColumns([c])
        ..where(where);
      return (await q.getSingle()).read(c) ?? 0;
    }

    n += await count(
      settings,
      settings.dirty & settings.key.isIn(SettingKeys.synced),
    );
    n += await count(interests, interests.dirty);
    n += await count(studyList, studyList.dirty);
    n += await count(ratings, ratings.dirty);
    n += await count(lessonProgress, lessonProgress.dirty);
    n += await count(quizResults, quizResults.dirty);
    n += await count(feedState, feedState.dirty);
    return n;
  }

  /// Every dirty row as a wire record (tombstones included).
  Future<List<SyncRecord>> dirtyRecords() async {
    final out = <SyncRecord>[];
    for (final r in await (select(
      settings,
    )..where((t) => t.dirty & t.key.isIn(SettingKeys.synced))).get()) {
      out.add(_settingRecord(r));
    }
    for (final r in await (select(
      interests,
    )..where((t) => t.dirty)).get()) {
      out.add(interestRecord(r));
    }
    for (final r in await (select(
      studyList,
    )..where((t) => t.dirty)).get()) {
      out.add(studyRecord(r));
    }
    for (final r in await (select(ratings)..where((t) => t.dirty)).get()) {
      out.add(ratingRecord(r));
    }
    for (final r in await (select(
      lessonProgress,
    )..where((t) => t.dirty)).get()) {
      out.add(progressRecord(r));
    }
    for (final r in await (select(
      quizResults,
    )..where((t) => t.dirty)).get()) {
      out.add(quizRecord(r));
    }
    for (final r in await (select(
      feedState,
    )..where((t) => t.dirty)).get()) {
      out.add(feedRecord(r));
    }
    return out;
  }

  // ---- acknowledgements ----

  /// The server applied [pushed]. Clears `dirty` only if the row is still
  /// exactly what was pushed (a newer local edit stays dirty); an
  /// acknowledged tombstone is removed for good (15.5).
  Future<void> ackApplied(SyncRecord pushed) => transaction(() async {
    final local = await localStamp(pushed.kind, pushed.id);
    if (local == null || !_same(local, pushed)) return;
    if (pushed.deleted) {
      await _removeRow(pushed.kind, pushed.id, pushed.updatedAt);
    } else {
      await _markClean(pushed.kind, pushed.id);
    }
  });

  /// The server kept its own copy ([stored]) instead of [pushed]: overwrite
  /// the local row with it, unless the user changed the row again since.
  Future<void> applySuperseded(SyncRecord pushed, SyncRecord stored) =>
      transaction(() async {
        final local = await localStamp(pushed.kind, pushed.id);
        if (local != null && !_same(local, pushed)) return;
        await _write(stored);
      });

  /// The server refused [pushed] (invalid_kind, invalid_data, too_large,
  /// quota). Retrying cannot help, so stop sending it; the local row stays.
  Future<void> dropRejected(SyncRecord pushed) => transaction(() async {
    final local = await localStamp(pushed.kind, pushed.id);
    if (local == null || !_same(local, pushed)) return;
    if (pushed.deleted) {
      await _removeRow(pushed.kind, pushed.id, pushed.updatedAt);
    } else {
      await _markClean(pushed.kind, pushed.id);
    }
  });

  bool _same(LocalStamp l, SyncRecord r) =>
      utcMs(l.updatedAt) == utcMs(r.updatedAt) && l.deleted == r.deleted;

  // ---- incoming ----

  /// A pulled record (15.5): applied when it wins by last-write-wins
  /// against the local row (newer, or equal and a delete). Returns whether
  /// it changed anything. Malformed data throws [FormatException].
  Future<bool> applyPulled(SyncRecord r) => transaction(() async {
    if (!SyncKind.all.contains(r.kind)) return false;
    if (r.kind == SyncKind.setting && !SettingKeys.synced.contains(r.id)) {
      return false;
    }
    final local = await localStamp(r.kind, r.id);
    if (r.kind == SyncKind.quizResult) {
      // Append-only: an attempt is never edited, only tombstoned.
      if (local == null) {
        if (r.deleted) return false;
        await _write(r);
        return true;
      }
      if (r.deleted) {
        await _removeRow(r.kind, r.id, r.updatedAt);
        return true;
      }
      if (local.dirty && !local.deleted) await _markClean(r.kind, r.id);
      return false;
    }
    if (local == null) {
      if (r.deleted) return false;
      await _write(r);
      return true;
    }
    if (!incomingWins(
      incomingAt: r.updatedAt,
      incomingDeleted: r.deleted,
      localAt: local.updatedAt,
      localDeleted: local.deleted,
    )) {
      // The very same version (our own push read back): nothing to send.
      if (local.dirty && _same(local, r)) await _markClean(r.kind, r.id);
      return false;
    }
    await _write(r);
    return true;
  });

  /// Writes a server record as clean: a live record is upserted, a
  /// tombstone removes the row (a setting goes back to its default).
  Future<void> _write(SyncRecord r) async {
    if (r.deleted) return _removeRow(r.kind, r.id, r.updatedAt);
    final d = r.data!;
    final at = utcMs(r.updatedAt);
    switch (r.kind) {
      case SyncKind.setting:
        final v = d['value'];
        if (v is! String) throw const FormatException('setting value');
        await into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: r.id,
            value: v,
            updatedAt: Value(at),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.interest:
        await into(interests).insertOnConflictUpdate(
          InterestsCompanion.insert(
            titleId: d['title_id'] as String,
            kind: d['kind'] as String,
            position: d['position'] as int,
            pickedAt: parseZ(d['picked_at']),
            updatedAt: Value(at),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.studyItem:
        await into(studyList).insertOnConflictUpdate(
          StudyListCompanion.insert(
            titleId: d['title_id'] as String,
            addedAt: parseZ(d['added_at']),
            updatedAt: Value(at),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.rating:
        await into(ratings).insertOnConflictUpdate(
          RatingsCompanion.insert(
            titleId: d['title_id'] as String,
            value: d['value'] as int,
            ratedAt: parseZ(d['rated_at']),
            updatedAt: Value(at),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.progress:
        await into(lessonProgress).insertOnConflictUpdate(
          LessonProgressCompanion.insert(
            lessonId: d['lesson_id'] as String,
            titleId: d['title_id'] as String,
            lessonIndex: d['lesson_index'] as int,
            lastOpenedAt: parseZ(d['last_opened_at']),
            completedAt: Value(parseZOrNull(d['completed_at'])),
            updatedAt: Value(at),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.quizResult:
        final existing = await (select(
          quizResults,
        )..where((t) => t.syncId.equals(r.id))).getSingleOrNull();
        final row = QuizResultsCompanion.insert(
          syncId: Value(r.id),
          titleId: d['title_id'] as String,
          score: d['score'] as int,
          total: d['total'] as int,
          questionIds: jsonEncode(d['question_ids'] as List<dynamic>),
          wrongIds: jsonEncode(d['wrong_ids'] as List<dynamic>),
          contentVersion: d['content_version'] as int,
          takenAt: parseZ(d['taken_at']),
          updatedAt: Value(at),
          deleted: const Value(false),
          dirty: const Value(false),
        );
        if (existing == null) {
          await into(quizResults).insert(row);
        } else {
          await (update(
            quizResults,
          )..where((t) => t.id.equals(existing.id))).write(row);
        }
      case SyncKind.feedItem:
        await into(feedState).insertOnConflictUpdate(
          FeedStateCompanion.insert(
            factId: d['fact_id'] as String,
            titleId: d['title_id'] as String,
            saved: Value(d['saved'] as bool),
            reaction: Value(d['reaction'] as int),
            seenAt: Value(parseZOrNull(d['seen_at'])),
            updatedAt: at,
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
    }
  }

  /// The sync columns of one local row (tombstones included), or null.
  Future<LocalStamp?> localStamp(String kind, String id) async {
    LocalStamp s(DateTime u, bool del, bool dirty) =>
        (updatedAt: u, deleted: del, dirty: dirty);
    switch (kind) {
      case SyncKind.setting:
        final r = await (select(
          settings,
        )..where((t) => t.key.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.interest:
        final (k, title) = splitInterestId(id);
        final r =
            await (select(interests)
                  ..where((t) => t.kind.equals(k) & t.titleId.equals(title)))
                .getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.studyItem:
        final r = await (select(
          studyList,
        )..where((t) => t.titleId.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.rating:
        final r = await (select(
          ratings,
        )..where((t) => t.titleId.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.progress:
        final r = await (select(
          lessonProgress,
        )..where((t) => t.lessonId.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.quizResult:
        final r = await (select(
          quizResults,
        )..where((t) => t.syncId.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
      case SyncKind.feedItem:
        final r = await (select(
          feedState,
        )..where((t) => t.factId.equals(id))).getSingleOrNull();
        return r == null ? null : s(r.updatedAt, r.deleted, r.dirty);
    }
    return null;
  }

  Future<void> _markClean(String kind, String id) async {
    switch (kind) {
      case SyncKind.setting:
        await (update(settings)..where((t) => t.key.equals(id))).write(
          const SettingsCompanion(dirty: Value(false)),
        );
      case SyncKind.interest:
        final (k, title) = splitInterestId(id);
        await (update(interests)
              ..where((t) => t.kind.equals(k) & t.titleId.equals(title)))
            .write(const InterestsCompanion(dirty: Value(false)));
      case SyncKind.studyItem:
        await (update(studyList)..where((t) => t.titleId.equals(id))).write(
          const StudyListCompanion(dirty: Value(false)),
        );
      case SyncKind.rating:
        await (update(ratings)..where((t) => t.titleId.equals(id))).write(
          const RatingsCompanion(dirty: Value(false)),
        );
      case SyncKind.progress:
        await (update(lessonProgress)..where((t) => t.lessonId.equals(id)))
            .write(const LessonProgressCompanion(dirty: Value(false)));
      case SyncKind.quizResult:
        await (update(quizResults)..where((t) => t.syncId.equals(id))).write(
          const QuizResultsCompanion(dirty: Value(false)),
        );
      case SyncKind.feedItem:
        await (update(feedState)..where((t) => t.factId.equals(id))).write(
          const FeedStateCompanion(dirty: Value(false)),
        );
    }
  }

  /// Physically removes a row once its deletion is settled with the
  /// server. Settings are never removed: they go back to the default.
  Future<void> _removeRow(String kind, String id, DateTime at) async {
    switch (kind) {
      case SyncKind.setting:
        await into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: id,
            value: SettingKeys.defaults[id] ?? '',
            updatedAt: Value(utcMs(at)),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
      case SyncKind.interest:
        final (k, title) = splitInterestId(id);
        await (delete(
          interests,
        )..where((t) => t.kind.equals(k) & t.titleId.equals(title))).go();
      case SyncKind.studyItem:
        await (delete(studyList)..where((t) => t.titleId.equals(id))).go();
      case SyncKind.rating:
        await (delete(ratings)..where((t) => t.titleId.equals(id))).go();
      case SyncKind.progress:
        await (delete(lessonProgress)..where((t) => t.lessonId.equals(id)))
            .go();
      case SyncKind.quizResult:
        await (delete(quizResults)..where((t) => t.syncId.equals(id))).go();
      case SyncKind.feedItem:
        await (delete(feedState)..where((t) => t.factId.equals(id))).go();
    }
  }

  // ---- bulk ----

  /// "Clear my data" (15.5): every live synced row becomes a dirty
  /// tombstone, stamped now, so the account and other devices clear too.
  Future<void> tombstoneAll() => transaction(() async {
    final at = utcMs(db.clock());
    const tomb = (deleted: Value(true), dirty: Value(true));
    await (update(interests)..where((t) => t.deleted.not())).write(
      InterestsCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
    await (update(studyList)..where((t) => t.deleted.not())).write(
      StudyListCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
    await (update(ratings)..where((t) => t.deleted.not())).write(
      RatingsCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
    await (update(lessonProgress)..where((t) => t.deleted.not())).write(
      LessonProgressCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
    await (update(quizResults)..where((t) => t.deleted.not())).write(
      QuizResultsCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
    await (update(feedState)..where((t) => t.deleted.not())).write(
      FeedStateCompanion(
        updatedAt: Value(at),
        deleted: tomb.deleted,
        dirty: tomb.dirty,
      ),
    );
  });

  // ---- row to record (15.1 `data` shapes) ----

  SyncRecord _settingRecord(SettingRow r) => SyncRecord(
    kind: SyncKind.setting,
    id: r.key,
    data: {'value': r.value},
    updatedAt: r.updatedAt,
  );

  static SyncRecord _rec(
    String kind,
    String id,
    DateTime at,
    bool deleted,
    Map<String, dynamic> Function() data,
  ) => deleted
      ? SyncRecord.tombstone(kind: kind, id: id, updatedAt: at)
      : SyncRecord(kind: kind, id: id, data: data(), updatedAt: at);

  static SyncRecord interestRecord(InterestRow r) => _rec(
    SyncKind.interest,
    '${r.kind}:${r.titleId}',
    r.updatedAt,
    r.deleted,
    () => {
      'kind': r.kind,
      'title_id': r.titleId,
      'position': r.position,
      'picked_at': zTime(r.pickedAt),
    },
  );

  static SyncRecord studyRecord(StudyItemRow r) => _rec(
    SyncKind.studyItem,
    r.titleId,
    r.updatedAt,
    r.deleted,
    () => {'title_id': r.titleId, 'added_at': zTime(r.addedAt)},
  );

  static SyncRecord ratingRecord(RatingRow r) => _rec(
    SyncKind.rating,
    r.titleId,
    r.updatedAt,
    r.deleted,
    () => {
      'title_id': r.titleId,
      'value': r.value,
      'rated_at': zTime(r.ratedAt),
    },
  );

  static SyncRecord progressRecord(LessonProgressRow r) => _rec(
    SyncKind.progress,
    r.lessonId,
    r.updatedAt,
    r.deleted,
    () => {
      'lesson_id': r.lessonId,
      'title_id': r.titleId,
      'lesson_index': r.lessonIndex,
      'last_opened_at': zTime(r.lastOpenedAt),
      'completed_at': r.completedAt == null ? null : zTime(r.completedAt!),
    },
  );

  static SyncRecord quizRecord(QuizResultRow r) => _rec(
    SyncKind.quizResult,
    r.syncId,
    r.updatedAt,
    r.deleted,
    () => {
      'id': r.syncId,
      'title_id': r.titleId,
      'score': r.score,
      'total': r.total,
      'question_ids': jsonDecode(r.questionIds),
      'wrong_ids': jsonDecode(r.wrongIds),
      'content_version': r.contentVersion,
      'taken_at': zTime(r.takenAt),
    },
  );

  static SyncRecord feedRecord(FeedStateRow r) => _rec(
    SyncKind.feedItem,
    r.factId,
    r.updatedAt,
    r.deleted,
    () => {
      'fact_id': r.factId,
      'title_id': r.titleId,
      'saved': r.saved,
      'reaction': r.reaction,
      'seen_at': r.seenAt == null ? null : zTime(r.seenAt!),
    },
  );
}

/// `topic_pick:roman-history` to (`topic_pick`, `roman-history`).
(String, String) splitInterestId(String id) {
  final i = id.indexOf(':');
  if (i <= 0) throw FormatException('interest id: $id');
  return (id.substring(0, i), id.substring(i + 1));
}
