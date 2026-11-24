// Library (DESIGN_SPEC 9.2.3, 7.4; CONTRACTS 3.2 row order): Featured hero,
// For you, one row per topic group, Because you liked X, the people row.
// The people row uses plain posters until Claude Design Prompt 2b (Q2).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models/catalogue.dart';
import '../../data/models/title.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/match/match_scores.dart';
import '../../domain/match/rows.dart';
import '../shared/catalogue_states.dart';
import '../shared/title_visuals.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final c = catalogue.value;
    if (c == null) {
      return SafeArea(
        child: catalogue.hasError
            ? CatalogueErrorState(error: catalogue.error)
            : const PosterRowSkeleton(posterWidth: 126),
      );
    }
    if (c.titles.isEmpty) {
      return const SafeArea(child: EmptyCatalogueState());
    }
    final match = ref.watch(matchProvider);
    final studyIds = ref.watch(studyIdsProvider);
    final ratings = ref.watch(ratingsProvider).value ?? const <RatingRow>[];

    PosterItem item(TitleSummary t) => PosterItem(
      id: t.id,
      data: posterData(t, c),
      matchPercent: match.pctOf(t.id),
    );
    void open(String id) => openTitleSheet(context, id);

    final featured = c.title(c.featuredId ?? '');
    // Most recent rating up names the "Because you liked" row (6.3).
    final likedId = ratings.where((r) => r.value == 1).firstOrNull?.titleId;
    final liked = likedId == null ? null : c.title(likedId);
    final people = [
      for (final g in c.groups.where((g) => g.people))
        ...c.titles.where((t) => t.group == g.key),
    ];

    return ListView(
      primary: false,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (featured != null)
          HeroBanner(
            art: titleArt(featured, c.image),
            lines: featured.posterLines,
            brief: featured.brief,
            onTap: () => open(featured.id),
            onStart: () => openReader(context, ref, featured.id),
          )
        else
          SizedBox(height: MediaQuery.paddingOf(context).top),
        PosterRow(
          title: 'For you',
          items: [
            for (final id in forYouIds(match, studyIds)) item(c.title(id)!),
          ],
          onTap: open,
        ),
        for (final g in c.groups.where((g) => !g.people))
          PosterRow(
            title: g.label,
            items: [
              for (final t in c.titles.where((t) => t.group == g.key)) item(t),
            ],
            onTap: open,
          ),
        if (liked != null)
          PosterRow(
            title: 'Because you liked ${liked.name}',
            items: [
              for (final id in becauseYouLikedIds(
                _matchTitles(c),
                liked.id,
                match,
              ))
                item(c.title(id)!),
            ],
            onTap: open,
          ),
        PosterRow(
          title: c.peopleRowLabel,
          items: [for (final t in people) item(t)],
          onTap: open,
        ),
      ],
    );
  }

  static List<MatchTitle> _matchTitles(Catalogue c) => [
    for (final t in c.titles) t.toMatchTitle(),
  ];
}
