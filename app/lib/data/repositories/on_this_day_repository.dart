// On This Day with its same-day cache (CONTRACTS 2.7): `cached_docs`
// key `otd:MM-DD`. Null means the card hides.
import 'dart:convert';

import '../db/app_database.dart';
import '../models/on_this_day.dart';

abstract interface class OnThisDaySource {
  /// GET /v1/on-this-day?date=MM-DD body.
  Future<String> onThisDayJson(String mmdd);
}

String mmddOf(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class OnThisDayRepository {
  OnThisDayRepository(this.db, this.source);

  final AppDatabase db;
  final OnThisDaySource source;

  Future<OnThisDay?> today(DateTime now) async {
    final mmdd = mmddOf(now);
    final key = 'otd:$mmdd';
    try {
      final body = await source.onThisDayJson(mmdd);
      final parsed = _usable(body, mmdd);
      if (parsed != null) {
        await db.contentCacheDao.putDoc(key, body);
        return parsed;
      }
    } catch (_) {
      // Offline or a bad payload: fall through to the same-day copy.
    }
    final cached = await db.contentCacheDao.doc(key);
    if (cached == null) return null;
    // The key has no year: last year's copy is not a same-day copy.
    final at = cached.fetchedAt.toLocal();
    if (at.year != now.year || at.month != now.month || at.day != now.day) {
      return null;
    }
    try {
      return _usable(cached.payload, mmdd);
    } catch (_) {
      return null;
    }
  }

  OnThisDay? _usable(String body, String mmdd) {
    final parsed = OnThisDay.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
    return parsed.date == mmdd && parsed.items.isNotEmpty ? parsed : null;
  }
}
