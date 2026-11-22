// Section headings: Home/Library rows (19/800, 12 to content) and the
// uppercase Settings section label (labelCaps, 10 to content).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: MxSpace.gutter),
  });

  final String title;

  /// Optional action at the right (e.g. a text button).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: MxText.section.copyWith(color: context.mx.text),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// "THEME", "TEXT SIZE": muted caps label above a control group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: MxText.labelCaps.copyWith(color: context.mx.textMuted),
      ),
    );
  }
}

/// Kicker: "CONTINUE · ROMAN EMPIRE", "ON THIS DAY · 21 NOVEMBER".
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;

  /// Topic tint on art, accentText on cards.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: MxText.kicker.copyWith(color: color ?? context.mx.accentText),
    );
  }
}
