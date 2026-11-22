// Rating row on the title sheet (DESIGN_SPEC 7.10): three 52 circles + note.
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';

/// Matches the drift `ratings` values (CONTRACTS 5.1): up, okay, down.
enum Rating {
  up(MxIcons.thumbsUp, 'Like', 'Noted. Similar topics move up.'),
  okay(MxIcons.minus, 'It is okay', 'Noted.'),
  down(MxIcons.thumbsDown, 'Not for me', 'Noted. You will see less like this.');

  const Rating(this.icon, this.label, this.note);
  final MxIcons icon;
  final String label;
  final String note;

  static const unratedNote = 'How does it look?';
}

class RatingButtons extends StatelessWidget {
  const RatingButtons({
    super.key,
    required this.value,
    required this.onChanged,
    this.showNote = true,
  });

  /// Single choice per title; null = not rated yet.
  final Rating? value;

  /// Tapping the selected rating again clears it (passes null).
  final ValueChanged<Rating?>? onChanged;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Row(
      children: [
        for (final r in Rating.values) ...[
          _RatingCircle(
            rating: r,
            selected: value == r,
            onTap: onChanged == null
                ? null
                : () => onChanged!(value == r ? null : r),
          ),
          if (r != Rating.values.last) const SizedBox(width: 10),
        ],
        if (showNote) ...[
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: MxMotion.reduced(context)
                  ? Duration.zero
                  : MxMotion.fade,
              child: Text(
                value?.note ?? Rating.unratedNote,
                key: ValueKey(value),
                style: MxText.sub.copyWith(color: c.textMuted),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingCircle extends StatelessWidget {
  const _RatingCircle({
    required this.rating,
    required this.selected,
    required this.onTap,
  });

  final Rating rating;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final reduced = MxMotion.reduced(context);
    return AnimatedScale(
      scale: selected && !reduced ? MxMotion.ratingScale : 1,
      duration: MxMotion.ratingSelect,
      curve: MxMotion.standard,
      child: SizedBox.square(
        dimension: 52,
        child: MxPressable(
          onPressed: onTap,
          semanticLabel: rating.label,
          selected: selected,
          fill: selected ? c.accent : null,
          border: BorderSide(color: selected ? c.accent : c.divider, width: 2),
          child: Center(
            child: MxIcon(
              rating.icon,
              size: 24,
              color: selected ? c.onAccent : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
