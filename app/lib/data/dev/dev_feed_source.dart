// Bundled stand-in for GET /v1/feed and /v1/on-this-day until S12.
import 'dart:convert';

import 'package:flutter/services.dart';

import '../repositories/feed_repository.dart';
import '../repositories/on_this_day_repository.dart';

class DevFeedSource implements FeedSource, OnThisDaySource {
  DevFeedSource(this.bundle);

  final AssetBundle bundle;

  /// Filters the sample response the way the server would: only the asked
  /// titles, at most [limit] facts, only the images those facts use.
  @override
  Future<String> feedJson(List<String> titleIds, {int limit = 10}) async {
    final json =
        jsonDecode(await bundle.loadString('assets/dev/feed.json', cache: false))
            as Map<String, dynamic>;
    final wanted = titleIds.toSet();
    final facts = (json['facts'] as List)
        .cast<Map<String, dynamic>>()
        .where((f) => wanted.contains(f['title_id']))
        .take(limit)
        .toList();
    final imageIds = {for (final f in facts) f['image_id']};
    return jsonEncode({
      ...json,
      'facts': facts,
      'images': (json['images'] as List)
          .cast<Map<String, dynamic>>()
          .where((i) => imageIds.contains(i['id']))
          .toList(),
    });
  }

  @override
  Future<String> onThisDayJson(String mmdd) =>
      bundle.loadString('assets/dev/on-this-day.json', cache: false);
}
