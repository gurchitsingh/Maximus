// Segmented choice (DESIGN_SPEC 7.2): Settings rows, onboarding group toggle.
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';

class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.compact = false,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String Function(T) labelOf;

  /// Group toggle style: h44, sized to content (pad 0 18) instead of
  /// h48 equal-width segments.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    Widget segment(T o) {
      final selected = o == value;
      return SizedBox(
        height: compact ? 44 : 48,
        child: MxPressable(
          onPressed: onChanged == null ? null : () => onChanged!(o),
          toggled: selected,
          fill: selected ? c.accent : null,
          border: BorderSide(color: selected ? c.accent : c.divider, width: 2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 8),
            child: Center(
              widthFactor: compact ? 1 : null,
              child: Text(
                labelOf(o),
                maxLines: 1,
                style: MxText.segment.copyWith(
                  color: selected ? c.onAccent : c.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    for (final o in options) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(compact ? segment(o) : Expanded(child: segment(o)));
    }
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: children,
    );
  }
}
