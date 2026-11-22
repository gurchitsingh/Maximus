// Title bottom sheet (DESIGN_SPEC 7.10, screens 2.4 and 2.5). Leaders and
// thinkers get the same sheet until S5 builds the person sheet (12.5).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../shared/title_visuals.dart';

/// Banner (h200 art) for the sheet page; the drag handle sits on top.
class TitleSheetBanner extends ConsumerWidget {
  const TitleSheetBanner({super.key, required this.titleId});
  final String titleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(catalogueProvider).value;
    final t = c?.title(titleId);
    if (c == null || t == null) {
      return ColoredBox(color: context.mx.surfaceRaised);
    }
    return TitleArt(data: titleArt(t, c.image));
  }
}

class TitleSheet extends ConsumerWidget {
  const TitleSheet({super.key, required this.titleId});
  final String titleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final catalogue = ref.watch(catalogueProvider);
    final t = catalogue.value?.title(titleId);
    if (catalogue.isLoading) return const TextSkeleton();
    if (t == null) {
      return ErrorState(
        title: 'No longer available',
        body: 'This title is not in the library any more.',
        onRetry: () => ref.invalidate(catalogueProvider),
      );
    }

    final match = ref.watch(matchProvider);
    final pct = match.pctOf(titleId);
    final reason = match.reasonOf(titleId);
    final added = ref.watch(studyIdsProvider).contains(titleId);
    final rating = switch (ref.watch(ratingMapProvider)[titleId]) {
      1 => Rating.up,
      0 => Rating.okay,
      -1 => Rating.down,
      _ => null,
    };
    final repo = ref.read(userStateRepositoryProvider);
    final tint = hexColor(t.tint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pct != null) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$pct% match',
                  style: MxText.buttonS.copyWith(color: c.accentText),
                ),
                if (reason != null)
                  TextSpan(
                    text: ' · $reason',
                    style: MxText.sub.copyWith(
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SheetLettering(
          lines: t.posterLines,
          kind: MxLettering.parse(t.lettering),
        ),
        const SizedBox(height: 12),
        Text(t.brief, style: MxText.bodyL.copyWith(color: c.text)),
        const SizedBox(height: 12),
        Text(lessonsMeta(t), style: MxText.meta.copyWith(color: c.textMuted)),
        const SizedBox(height: 16),
        RatingButtons(
          value: rating,
          onChanged: (r) => repo.setRating(titleId, switch (r) {
            Rating.up => 1,
            Rating.okay => 0,
            Rating.down => -1,
            null => null,
          }),
        ),
        const SizedBox(height: 16),
        TintButton(
          label: added ? 'Continue' : 'Start',
          tint: tint,
          onPressed: t.lessonCount == 0
              ? null
              : () => openReader(context, ref, titleId, closeSheetFirst: true),
        ),
        const SizedBox(height: 12),
        AccentOutlineButton(
          label: added ? 'Added to study list' : 'Add to study list',
          icon: added ? MxIcons.check : MxIcons.plus,
          toggled: added,
          onPressed: () => repo.setOnStudyList(titleId, !added),
        ),
      ],
    );
  }
}
