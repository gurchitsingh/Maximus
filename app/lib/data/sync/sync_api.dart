// GET and POST /v1/me/sync (CONTRACTS 15.3). Bearer auth comes from the
// ApiClient's interceptor (one refresh and one retry on 401, 14.5).
import '../api/api_client.dart';
import '../api/api_error.dart';
import 'sync_record.dart';

/// Server limits (15.3).
abstract final class SyncLimits {
  static const pushBatch = 200; // the app's batch size (15.5); server max 500
  static const pullLimit = 200;
}

class PullPage {
  const PullPage({
    required this.records,
    required this.cursor,
    required this.hasMore,
    required this.reset,
  });

  final List<SyncRecord> records;
  final int cursor;
  final bool hasMore;

  /// `since` is older than the tombstone horizon: pull again from 0.
  final bool reset;
}

class PushResult {
  const PushResult({
    required this.applied,
    required this.superseded,
    required this.rejected,
  });

  /// `kind\0id` of each accepted record.
  final Set<String> applied;

  /// The server's own copies that beat ours, by `kind\0id`.
  final Map<String, SyncRecord> superseded;

  /// `kind\0id` -> reason (invalid_kind, invalid_data, too_large, quota).
  final Map<String, String> rejected;
}

class SyncApi {
  SyncApi(this.client);

  final ApiClient client;

  static const path = '/v1/me/sync';

  Future<PullPage> pull(int since, {int limit = SyncLimits.pullLimit}) async {
    final j = await client.send('GET', '$path?since=$since&limit=$limit');
    final raw = j?['records'];
    final cursor = j?['cursor'];
    if (raw is! List || cursor is! int) {
      throw const ApiException(
        code: ApiException.badResponse,
        message: 'sync pull without records or cursor',
      );
    }
    final records = <SyncRecord>[];
    for (final r in raw) {
      try {
        records.add(SyncRecord.fromJson((r as Map).cast<String, dynamic>()));
      } on Object {
        // A record this app cannot read is skipped, never fatal.
      }
    }
    return PullPage(
      records: records,
      cursor: cursor,
      hasMore: j?['has_more'] == true,
      reset: j?['reset'] == true,
    );
  }

  Future<PushResult> push(List<SyncRecord> records) async {
    assert(records.isNotEmpty && records.length <= 500);
    final j = await client.send(
      'POST',
      path,
      body: {'records': [for (final r in records) r.toJson()]},
    );
    String key(Object? kind, Object? id) => '$kind\u0000$id';
    final applied = <String>{
      for (final a in (j?['applied'] as List<dynamic>? ?? const []))
        if (a is Map) key(a['kind'], a['id']),
    };
    final superseded = <String, SyncRecord>{};
    for (final s in (j?['superseded'] as List<dynamic>? ?? const [])) {
      try {
        final r = SyncRecord.fromJson((s as Map).cast<String, dynamic>());
        superseded[r.key] = r;
      } on Object {
        // Unreadable: the row stays dirty and is retried next run.
      }
    }
    final rejected = <String, String>{
      for (final x in (j?['rejected'] as List<dynamic>? ?? const []))
        if (x is Map) key(x['kind'], x['id']): '${x['reason']}',
    };
    return PushResult(
      applied: applied,
      superseded: superseded,
      rejected: rejected,
    );
  }
}
