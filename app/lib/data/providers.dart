// Riverpod wiring for the data layer. main() overrides [databaseProvider];
// tests override it with an in-memory database.
import 'dart:async' show unawaited;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/util/image_cache.dart';
import '../domain/match/match_scores.dart';
import 'api/api_client.dart';
import 'api/api_content_source.dart';
import 'db/app_database.dart';
import 'dev/dev_content_source.dart';
import 'models/catalogue.dart';
import 'models/title.dart';
import 'repositories/content_repository.dart';
import 'repositories/content_source.dart';
import 'repositories/user_state_repository.dart';

final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Bundled samples until S12 wires the API.
final contentSourceProvider = Provider<ContentSource>(
  (_) => DevContentSource(rootBundle),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(
    ref.watch(databaseProvider),
    ref.watch(contentSourceProvider),
  ),
);

final userStateRepositoryProvider = Provider<UserStateRepository>(
  (ref) => UserStateRepository(ref.watch(databaseProvider)),
);

final catalogueProvider = FutureProvider<Catalogue>(
  (ref) => ref.watch(contentRepositoryProvider).catalogue(),
);

/// A title's full payload, cached whole on first open (CONTRACTS 3.6).
final titleDetailProvider = FutureProvider.family<TitleDetail, String>((
  ref,
  id,
) async {
  final catalogue = await ref.watch(catalogueProvider.future);
  return ref
      .watch(contentRepositoryProvider)
      .title(id, catalogueVersion: catalogue.title(id)?.contentVersion);
});

// ---- user state streams (drift watch queries) ----

final studyListProvider = StreamProvider<List<StudyItemRow>>(
  (ref) => ref.watch(databaseProvider).userStateDao.watchStudyList(),
);

final ratingsProvider = StreamProvider<List<RatingRow>>(
  (ref) => ref.watch(databaseProvider).userStateDao.watchRatings(),
);

final progressProvider = StreamProvider<List<LessonProgressRow>>(
  (ref) => ref.watch(databaseProvider).userStateDao.watchProgress(),
);

final interestsProvider = StreamProvider<List<InterestRow>>(
  (ref) => ref.watch(databaseProvider).userStateDao.watchInterests(),
);

final feedStateProvider = StreamProvider<List<FeedStateRow>>(
  (ref) => ref.watch(databaseProvider).userStateDao.watchFeedState(),
);

final settingsMapProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchAll(),
);

/// Study list ids, for quick "is it added" checks.
final studyIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final r
        in ref.watch(studyListProvider).value ?? const <StudyItemRow>[])
      r.titleId,
  },
);

/// title id -> -1 | 0 | 1.
final ratingMapProvider = Provider<Map<String, int>>(
  (ref) => {
    for (final r in ref.watch(ratingsProvider).value ?? const <RatingRow>[])
      r.titleId: r.value,
  },
);

/// Progress of one title (lesson_count from the catalogue).
final titleProgressProvider = Provider.family<TitleProgress, String>((ref, id) {
  final count = ref.watch(catalogueProvider).value?.title(id)?.lessonCount ?? 0;
  return TitleProgress(
    titleId: id,
    lessonCount: count,
    rows: ref.watch(progressProvider).value ?? const <LessonProgressRow>[],
  );
});

// ---- match % (CONTRACTS 6) ----

extension TitleSummaryMatch on TitleSummary {
  MatchTitle toMatchTitle() => MatchTitle(
    id: id,
    name: name,
    group: group,
    era: era,
    region: region,
    themes: themes,
    rank: rank,
    lessonCount: lessonCount,
    linkedTitleIds: linkedTitleIds,
  );
}

/// The signals of 6.1, gathered from the drift tables.
final matchSignalsProvider = Provider<MatchSignals>((ref) {
  final interests = ref.watch(interestsProvider).value ?? const <InterestRow>[];
  final progress =
      ref.watch(progressProvider).value ?? const <LessonProgressRow>[];
  final feed = ref.watch(feedStateProvider).value ?? const <FeedStateRow>[];

  final completed = <String, int>{};
  for (final p in progress) {
    if (p.completedAt != null) {
      completed[p.titleId] = (completed[p.titleId] ?? 0) + 1;
    }
  }
  final up = <String, int>{}, down = <String, int>{};
  for (final f in feed) {
    if (f.saved || f.reaction == 1) up[f.titleId] = (up[f.titleId] ?? 0) + 1;
    if (f.reaction == -1) down[f.titleId] = (down[f.titleId] ?? 0) + 1;
  }
  return MatchSignals(
    topicPicks: [
      for (final i in interests)
        if (i.kind == 'topic_pick') i.titleId,
    ],
    leaderPicks: [
      for (final i in interests)
        if (i.kind == 'leader_pick') i.titleId,
    ],
    ratings: ref.watch(ratingMapProvider),
    studyList: [
      for (final r
          in ref.watch(studyListProvider).value ?? const <StudyItemRow>[])
        r.titleId,
    ],
    lessonsCompleted: completed,
    feed: {
      for (final id in {...up.keys, ...down.keys})
        id: FeedCounts(likedOrSaved: up[id] ?? 0, disliked: down[id] ?? 0),
    },
  );
});

final matchTitlesProvider = Provider<List<MatchTitle>>(
  (ref) => [
    for (final t
        in ref.watch(catalogueProvider).value?.titles ?? const <TitleSummary>[])
      t.toMatchTitle(),
  ],
);

/// Recomputed on every signal change (6.3): about 80 titles, under 1 ms.
final matchProvider = Provider<MatchResult>(
  (ref) => matchScores(
    ref.watch(matchTitlesProvider),
    ref.watch(matchSignalsProvider),
  ),
);

// ---- /v1 API (S12, CONTRACTS 3) ----
// main.dart overrides contentSourceProvider, feedSourceProvider,
// onThisDaySourceProvider and creditsSourceProvider with
// [apiContentSourceProvider]; tests keep the bundled dev sources.

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());

final apiContentSourceProvider = Provider<ApiContentSource>(
  (ref) => ApiContentSource(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider).contentCacheDao,
    prefetchImages: (urls) => unawaited(prefetchImages(urls)),
  ),
);

/// Background refetch of stale study-list titles (3.6). Home watches it.
final staleTitlesRefreshProvider = FutureProvider<int>((ref) async {
  final catalogue = await ref.watch(catalogueProvider.future);
  final rows = await ref.watch(studyListProvider.future);
  return ref
      .watch(contentRepositoryProvider)
      .refreshStale(catalogue, [for (final r in rows) r.titleId]);
});
