// The sync wire envelope (CONTRACTS 15.2) and the last-write-wins rule
// (15.3, D38).
import 'package:meta/meta.dart';

/// The `kind` values of CONTRACTS 15.1.
abstract final class SyncKind {
  static const setting = 'setting';
  static const interest = 'interest';
  static const studyItem = 'study_item';
  static const rating = 'rating';
  static const progress = 'progress';
  static const quizResult = 'quiz_result';
  static const feedItem = 'feed_item';

  static const all = {
    setting,
    interest,
    studyItem,
    rating,
    progress,
    quizResult,
    feedItem,
  };
}

/// UTC, milliseconds, as the server stores it.
DateTime utcMs(DateTime t) =>
    DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);

/// `2026-11-24T10:00:00.000Z` (15.2: UTC with `Z`, at most milliseconds).
String zTime(DateTime t) => utcMs(t).toIso8601String();

DateTime parseZ(Object? v) {
  if (v is! String || !v.endsWith('Z')) {
    throw FormatException('not a UTC time: $v');
  }
  return utcMs(DateTime.parse(v));
}

DateTime? parseZOrNull(Object? v) => v == null ? null : parseZ(v);

@immutable
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
    this.seq,
  });

  factory SyncRecord.fromJson(Map<String, dynamic> j) {
    final kind = j['kind'], id = j['id'], deleted = j['deleted'] ?? false;
    final data = j['data'], seq = j['seq'];
    if (kind is! String || id is! String || deleted is! bool) {
      throw const FormatException('bad sync record');
    }
    if (!deleted && data is! Map) {
      throw const FormatException('live sync record without data');
    }
    return SyncRecord(
      kind: kind,
      id: id,
      data: deleted ? null : (data as Map).cast<String, dynamic>(),
      updatedAt: parseZ(j['updated_at']),
      deleted: deleted,
      seq: seq is int ? seq : null,
    );
  }

  /// A tombstone (15.2): `data` is null.
  const SyncRecord.tombstone({
    required this.kind,
    required this.id,
    required this.updatedAt,
    this.seq,
  }) : data = null,
       deleted = true;

  final String kind;
  final String id;
  final Map<String, dynamic>? data;
  final DateTime updatedAt;
  final bool deleted;

  /// Set by the server only; never sent.
  final int? seq;

  /// The push body form: no `seq` (15.2: clients send none).
  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'data': deleted ? null : data,
    'updated_at': zTime(updatedAt),
    'deleted': deleted,
  };

  String get key => '$kind\u0000$id';

  @override
  String toString() =>
      'SyncRecord($kind/$id ${zTime(updatedAt)}${deleted ? ' deleted' : ''})';
}

/// The server's rule (15.3): the newer `updated_at` wins; at the same
/// instant a delete beats an edit. True when [incoming] should replace the
/// local copy described by [localAt] and [localDeleted].
bool incomingWins({
  required DateTime incomingAt,
  required bool incomingDeleted,
  required DateTime localAt,
  required bool localDeleted,
}) {
  final a = utcMs(incomingAt), b = utcMs(localAt);
  if (a.isAfter(b)) return true;
  return a == b && incomingDeleted && !localDeleted;
}
