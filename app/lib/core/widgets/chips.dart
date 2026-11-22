// Chips: suggestion (7.14), source (7.14), topic tag on art (7.17).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';

/// Suggested question chip: h44, 2 dp divider border. Null onPressed = the
/// resting/offline state (opacity 0.4, inert).
class SuggestionChip extends StatelessWidget {
  const SuggestionChip({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      height: 44,
      child: MxPressable(
        onPressed: onPressed,
        border: BorderSide(color: c.divider, width: 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: MxText.chip.copyWith(color: c.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of suggestion chips (gap 8, pad 8 20 4).
class SuggestionChipRow extends StatelessWidget {
  const SuggestionChipRow({
    super.key,
    required this.labels,
    required this.onSelected,
  });

  final List<String> labels;

  /// Null disables every chip.
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          for (final l in labels) ...[
            SuggestionChip(
              label: l,
              onPressed: onSelected == null ? null : () => onSelected!(l),
            ),
            if (l != labels.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Source chip inside an assistant bubble: "From lesson 4".
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    // 28 tall per spec, below the 48 dp target: S15 should pad the hit area.
    return MxPressable(
      onPressed: onPressed,
      border: BorderSide(color: c.accentText),
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MxIcon(MxIcons.book, size: 14, color: c.accentText),
              const SizedBox(width: 6),
              Text(label, style: MxText.tag.copyWith(color: c.accentText)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Topic tag on feed artwork: h30, dark glass, text in the topic tint.
class TopicTag extends StatelessWidget {
  const TopicTag({super.key, required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MxFixed.topicTagBg,
        borderRadius: BorderRadius.circular(MxRadius.navPill),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: MxText.feedback.copyWith(color: tint),
        maxLines: 1,
      ),
    );
  }
}
