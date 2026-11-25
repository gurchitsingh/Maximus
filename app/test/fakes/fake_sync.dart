// In-memory /v1/me/sync (CONTRACTS 15.3), with the same rules as
// backend/app/services/sync.py: last write wins by updated_at, a delete
// beats an edit at the same instant, quiz results are append-only, and a
// per-user seq is the pull cursor. Plus switches to inject failures.
import 'package:maximus/data/sync/sync_record.dart';

class StoredRecord {
  StoredRecord(this.kind, this.id, this.data, this.updatedAt, this.deleted);

  final String kind;
  final String id;
  Map<String, dynamic>? data;
  DateTime updatedAt;
  bool deleted;
  int seq = 0;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'data': deleted ? null : data,
    'updated_at': zTime(updatedAt),
    'deleted': deleted,
    'seq': seq,
  };
}

class FakeSyncServer {
  /// user id -> kind\0id -> record.
  final _store = <String, Map<String, StoredRecord>>{};
  final _seq = <String, int>{};

  /// Pulls with `0 < since < purgedSeq` get `reset: true` (15.4).
  final purgedSeq = <String, int>{};

  /// The next sync calls answer with these (status, code), in order.
  final failures = <(int, String)>[];

  /// Pushes are applied but not acknowledged (the response is lost).
  bool loseAcks = false;

  /// Every pushed batch, as sent.
  final pushes = <List<Map<String, dynamic>>>[];

  /// Every pull's `since`.
  final pulls = <int>[];

  /// Blocks each sync call until completed (single-flight tests).
  Future<void>? gate;

  Map<String, StoredRecord> recordsOf(String userId) =>
      _store.putIfAbsent(userId, () => {});

  StoredRecord? record(String userId, String kind, String id) =>
      recordsOf(userId)['$kind\u0000$id'];

  /// Live (not deleted) records of [kind] for [userId].
  List<StoredRecord> live(String userId, String kind) => [
    for (final r in recordsOf(userId).values)
      if (r.kind == kind && !r.deleted) r,
  ];

  /// A record written by "another device".
  void put(
    String userId,
    String kind,
    String id,
    Map<String, dynamic>? data,
    DateTime updatedAt, {
    bool deleted = false,
  }) {
    final r = StoredRecord(kind, id, data, updatedAt, deleted);
    r.seq = _next(userId);
    recordsOf(userId)['$kind\u0000$id'] = r;
  }

  int _next(String userId) => _seq[userId] = (_seq[userId] ?? 0) + 1;

  bool _wins(StoredRecord? stored, String kind, DateTime at, bool deleted) {
    if (stored == null) return true;
    if (kind == 'quiz_result') return deleted && !stored.deleted;
    if (at.isAfter(stored.updatedAt)) return true;
    return at == stored.updatedAt && deleted && !stored.deleted;
  }

  Map<String, Object?> push(String userId, List<dynamic> records) {
    pushes.add([for (final r in records) (r as Map).cast<String, dynamic>()]);
    final applied = <Map<String, Object?>>[];
    final superseded = <Map<String, Object?>>[];
    final rejected = <Map<String, Object?>>[];
    for (final raw in records.cast<Map<String, dynamic>>()) {
      final kind = raw['kind'] as String, id = raw['id'] as String;
      if (!SyncKind.all.contains(kind)) {
        rejected.add({'kind': kind, 'id': id, 'reason': 'invalid_kind'});
        continue;
      }
      if (kind == 'setting' && id == 'install_id') {
        rejected.add({'kind': kind, 'id': id, 'reason': 'invalid_data'});
        continue;
      }
      final deleted = raw['deleted'] as bool;
      final at = parseZ(raw['updated_at']);
      final key = '$kind\u0000$id';
      final stored = recordsOf(userId)[key];
      if (!_wins(stored, kind, at, deleted)) {
        superseded.add(stored!.toJson());
        continue;
      }
      final r = stored ?? StoredRecord(kind, id, null, at, deleted);
      r
        ..data = deleted ? null : (raw['data'] as Map).cast<String, dynamic>()
        ..updatedAt = at
        ..deleted = deleted
        ..seq = _next(userId);
      recordsOf(userId)[key] = r;
      applied.add({'kind': kind, 'id': id, 'seq': r.seq});
    }
    return {
      'applied': loseAcks ? <Object>[] : applied,
      'superseded': superseded,
      'rejected': rejected,
      'cursor': _seq[userId] ?? 0,
    };
  }

  Map<String, Object?> pull(String userId, int since, int limit) {
    pulls.add(since);
    final purged = purgedSeq[userId] ?? 0;
    if (since > 0 && since < purged) {
      return {
        'records': <Object>[],
        'cursor': 0,
        'has_more': false,
        'reset': true,
      };
    }
    final rows =
        recordsOf(userId).values.where((r) => r.seq > since).toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = rows.take(limit).toList();
    return {
      'records': [for (final r in page) r.toJson()],
      'cursor': page.isEmpty ? since : page.last.seq,
      'has_more': rows.length > limit,
      'reset': false,
    };
  }
}
