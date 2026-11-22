// Title surfaces for Home, Library and Study: hero banner (DESIGN_SPEC 7.4),
// resume card (7.5), study rows (7.6) and the poster row (7.3, 3).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';
import 'poster_card.dart';
import 'progress_bars.dart';
import 'section_header.dart';
import 'title_art.dart';

/// Library "Featured": full width, h430, art cover, scrim, title + Start.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.art,
    required this.lines,
    required this.brief,
    required this.onTap,
    required this.onStart,
    this.startLabel = 'Start',
  });

  final ArtData art;
  final List<String> lines;
  final String brief;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final String startLabel;

  static const _shadow = [
    Shadow(color: MxFixed.heroShadow, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    final name = lines.where((l) => l.trim().isNotEmpty).join(' ');
    return Semantics(
      button: true,
      label: 'Featured: $name',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 430,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TitleArt(data: art),
              const ArtScrim(alpha: 0.96, from: 0.06, to: 0.6),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        'FEATURED',
                        style: MxText.kicker.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 15 * 0.34,
                          color: MxFixed.heroTitle,
                          shadows: const [
                            Shadow(
                              color: MxFixed.heroShadow,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final l in lines)
                      if (l.trim().isNotEmpty)
                        Text(
                          l.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: MxText.heroTitle.copyWith(
                            color: MxFixed.heroTitle,
                            shadows: _shadow,
                          ),
                        ),
                    const SizedBox(height: 10),
                    Text(
                      brief,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: MxText.body.copyWith(
                        height: 1.4,
                        color: MxFixed.textOnArt,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PillCta(
                      label: startLabel,
                      tint: art.tint,
                      onPressed: onStart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home "Continue" card: h190, radius 22, kicker in tint, progress + Resume.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.art,
    required this.titleName,
    required this.lessonLine,
    required this.progress,
    required this.onTap,
  });

  final ArtData art;
  final String titleName;

  /// "Lesson 4: Why the Republic fell".
  final String lessonLine;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MxRadius.resume);
    return Semantics(
      button: true,
      label: 'Continue $titleName. $lessonLine',
      excludeSemantics: true,
      child: MxPressable(
        onPressed: onTap,
        borderRadius: radius,
        overlay: const Color(0x24000000),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TitleArt(data: art),
                const ArtScrim(alpha: 0.94, from: 0.08, to: 0.7),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTINUE · ${titleName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MxText.kicker.copyWith(color: art.tint),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lessonLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MxText.cardTitle.copyWith(
                          color: MxFixed.textOnArt,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: MxProgressBar(
                              value: progress,
                              fill: art.tint,
                              track: MxFixed.artTrack,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Visual only: the whole card is the button.
                          IgnorePointer(
                            child: PillCta(
                              label: 'Resume',
                              size: PillSize.resume,
                              tint: art.tint,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Study row. [card] = Study tab variant (surface card, name 17, remove X);
/// otherwise the Home variant (no card).
class StudyRow extends StatelessWidget {
  const StudyRow({
    super.key,
    required this.art,
    required this.name,
    required this.subtitle,
    required this.progress,
    required this.onTap,
    this.card = false,
    this.onRemove,
  });

  final ArtData art;
  final String name;

  /// "Lesson 4 of 8" or "Not started".
  final String subtitle;
  final double progress;
  final VoidCallback? onTap;
  final bool card;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final body = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MxRadius.thumb),
          child: SizedBox.square(dimension: 64, child: TitleArt(data: art)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (card ? MxText.rowTitleL : MxText.rowTitle).copyWith(
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: MxText.sub.copyWith(color: c.textMuted)),
              const SizedBox(height: 8),
              MxProgressBar(value: progress, fill: art.tint),
            ],
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          MxIconButton(
            icon: MxIcons.x,
            size: 20,
            color: c.textMuted,
            label: 'Remove $name',
            onPressed: onRemove,
          ),
        ],
      ],
    );
    final radius = BorderRadius.circular(card ? MxRadius.card : MxRadius.thumb);
    final content = card
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: radius,
              border: Border.all(color: c.divider),
            ),
            child: body,
          )
        : body;
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$name, $subtitle',
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          overlayColor: WidgetStatePropertyAll(c.text.withValues(alpha: 0.08)),
          child: content,
        ),
      ),
    );
  }
}

/// One poster item of a row.
@immutable
class PosterItem {
  const PosterItem({
    required this.id,
    required this.data,
    this.matchPercent,
  });

  final String id;
  final PosterData data;
  final int? matchPercent;
}

/// Section heading + horizontal poster row (gap 12, 20 side padding, edge
/// to edge). Hidden when empty (CONTRACTS 3.2 "rows with no titles").
class PosterRow extends StatelessWidget {
  const PosterRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.posterWidth = 126,
  });

  final String title;
  final List<PosterItem> items;
  final ValueChanged<String> onTap;
  final double posterWidth;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: MxSpace.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: MxSpace.headingToContent),
          SizedBox(
            height: posterWidth * 1.5,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MxSpace.gutter),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: MxSpace.posterRowGap),
              itemBuilder: (_, i) => PosterCard(
                key: ValueKey(items[i].id),
                data: items[i].data,
                width: posterWidth,
                matchPercent: items[i].matchPercent,
                onTap: () => onTap(items[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
