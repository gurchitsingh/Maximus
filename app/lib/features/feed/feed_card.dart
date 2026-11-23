// Feed card (DESIGN_SPEC 7.17): art or typographic bg, scrim, topic tag,
// fact, Go deeper, credit line, and the Save / Like / Dislike column.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/title.dart';
import '../../data/repositories/feed_repository.dart';
import '../reader/lesson_body.dart' show showImageDetails;
import '../shared/title_visuals.dart';
import 'feed_providers.dart';

/// The topic tag's glass, opaque, for the tint contrast check.
const _tagBacking = Color(0xFF0F0D0A);

class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.entry,
    required this.onGoDeeper,
    required this.onSave,
    required this.onLike,
    required this.onDislike,
  });

  final FeedEntry entry;
  final VoidCallback onGoDeeper;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final t = entry.title;
    final image = entry.image;
    final top = MediaQuery.paddingOf(context).top + 20;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null)
          // Typographic card: the title's bg, never a grey placeholder.
          ColoredBox(color: hexColor(t.bg))
        else
          TitleArt(data: imageArt(t, image)),
        const ArtScrim(alpha: 0.94, from: 0.18, to: 0.58),
        Positioned(
          top: top,
          left: 20,
          right: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TopicTag(
              label: t.name,
              tint: readableTint(hexColor(t.tint), _tagBacking),
            ),
          ),
        ),
        Positioned(
          top: top + 42,
          left: 20,
          right: 84,
          bottom: 22,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _FactText(entry.fact.text)),
              const SizedBox(height: 14),
              PillCta(
                label: 'Go deeper',
                size: PillSize.goDeeper,
                onPressed: onGoDeeper,
              ),
              if (image != null) _CardCredit(image: image),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 22,
          child: _FeedActions(
            factId: entry.fact.id,
            onSave: onSave,
            onLike: onLike,
            onDislike: onDislike,
          ),
        ),
      ],
    );
  }
}

/// Scales down instead of clipping at very large system text sizes.
class _FactText extends StatelessWidget {
  const _FactText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: box.maxWidth,
          child: Text(
            text,
            style: MxText.feedFact.copyWith(color: MxFixed.textOnArt),
          ),
        ),
      ),
    );
  }
}

/// The image's credit line (CONTRACTS 2.8); tap opens its details.
class _CardCredit extends StatelessWidget {
  const _CardCredit({required this.image});
  final ContentImage image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Image credit: ${image.creditLine}. Show details.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showImageDetails(context, image),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MxSpace.minTouch),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(
              image.creditLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MxText.caption.copyWith(
                color: MxFixed.textOnArt.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedActions extends ConsumerWidget {
  const _FeedActions({
    required this.factId,
    required this.onSave,
    required this.onLike,
    required this.onDislike,
  });

  final String factId;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(feedFactStateProvider(factId));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FeedActionButton(
          icon: MxIcons.bookmark,
          label: 'Save',
          active: s.saved,
          onPressed: onSave,
        ),
        const SizedBox(height: 8),
        FeedActionButton(
          icon: MxIcons.thumbsUp,
          label: 'Like',
          active: s.reaction == 1,
          onPressed: onLike,
        ),
        const SizedBox(height: 8),
        FeedActionButton(
          icon: MxIcons.thumbsDown,
          label: 'Dislike',
          active: s.reaction == -1,
          onPressed: onDislike,
        ),
      ],
    );
  }
}
