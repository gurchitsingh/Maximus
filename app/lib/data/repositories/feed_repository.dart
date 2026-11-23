// Feed pools (CONTRACTS 7.2): own facts from cached study-list titles, and
// the "try this" facts from /v1/feed (bundled assets until S12).
import 'dart:convert';

import 'package:meta/meta.dart';

import '../models/catalogue.dart';
import '../models/title.dart';
import 'content_repository.dart';

abstract interface class FeedSource {
  /// GET /v1/feed?title_ids=...&limit=... body.
  Future<String> feedJson(List<String> titleIds, {int limit = 10});
}

/// A fact with everything its card needs.
@immutable
class FeedEntry {
  const FeedEntry({
    required this.fact,
    required this.title,
    required this.image,
    required this.isTry,
    required this.lessonId,
  });

  final FeedFact fact;
  final TitleSummary title;
  final ContentImage? image;
  final bool isTry;

  /// Go deeper target: the fact's lesson, else lesson 1. Null on try cards
  /// and titles without lessons (they open the title sheet).
  final String? lessonId;
}

class FeedRepository {
  FeedRepository(this.content, this.source);

  final ContentRepository content;
  final FeedSource source;

  /// Facts of the study-list titles. A title that cannot be loaded (offline,
  /// never cached) is skipped.
  Future<List<FeedEntry>> ownEntries(
    Catalogue catalogue,
    Iterable<String> studyIds,
  ) async {
    final out = <FeedEntry>[];
    for (final id in studyIds) {
      final summary = catalogue.title(id);
      if (summary == null) continue;
      final TitleDetail detail;
      try {
        detail = await content.title(
          id,
          catalogueVersion: summary.contentVersion,
        );
      } catch (_) {
        continue;
      }
      for (final fact in detail.feedFacts) {
        out.add(
          FeedEntry(
            fact: fact,
            title: summary,
            image: detail.image(fact.imageId),
            isTry: false,
            lessonId:
                detail.lesson(fact.lessonId ?? '')?.id ??
                (detail.lessons.isEmpty ? null : detail.lessons.first.id),
          ),
        );
      }
    }
    return out;
  }

  /// The try pool. Any failure means no try cards this session.
  Future<List<FeedEntry>> tryEntries(
    Catalogue catalogue,
    List<String> titleIds, {
    int limit = 10,
  }) async {
    if (titleIds.isEmpty) return const [];
    try {
      final body = await source.feedJson(titleIds, limit: limit);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final images = {
        for (final x in json['images'] as List? ?? const <Object?>[])
          (x as Map<String, dynamic>)['id'] as String: ContentImage.fromJson(x),
      };
      final wanted = titleIds.toSet();
      return [
        for (final x in json['facts'] as List? ?? const <Object?>[])
          if (_entry(x as Map<String, dynamic>, catalogue, images, wanted)
              case final FeedEntry e)
            e,
      ];
    } catch (_) {
      return const [];
    }
  }

  FeedEntry? _entry(
    Map<String, dynamic> json,
    Catalogue catalogue,
    Map<String, ContentImage> images,
    Set<String> wanted,
  ) {
    final fact = FeedFact.fromJson(json);
    final title = catalogue.title(fact.titleId);
    if (title == null || !wanted.contains(fact.titleId)) return null;
    return FeedEntry(
      fact: fact,
      title: title,
      image: images[fact.imageId],
      isTry: true,
      lessonId: null,
    );
  }
}
