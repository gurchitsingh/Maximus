// Custom icon set from DESIGN_SPEC 10.4: 24x24, stroke 2, round caps and
// joins, no fill (play is filled). Drawn from the spec paths, not a library.
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

enum MxIcons {
  home('<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>'),
  library('<path d="M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z"/>'),
  feed(
    '<path d="M8.5 3h7A2.5 2.5 0 0 1 18 5.5v13a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 6 18.5v-13A2.5 2.5 0 0 1 8.5 3z M10.5 9.5v5l4-2.5z"/>',
  ),
  bookmark('<path d="M6.5 3.5h11v17l-5.5-4-5.5 4z"/>'),
  book(
    '<path d="M4 5.5C6 4.5 9 4.5 12 6c3-1.5 6-1.5 8-.5v13c-2-1-5-1-8 .5-3-1.5-6-1.5-8-.5z M12 6v13.5"/>',
  ),
  chat('<path d="M4 5h16v11H10l-5 4v-4H4z"/>'),
  quiz(
    '<path d="M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .9-1 1.7 M12 17h.01"/>',
  ),
  sun(
    '<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>',
  ),
  moon('<path d="M20 14A8 8 0 0 1 10 4a8 8 0 1 0 10 10z"/>'),

  /// Not in the bundle. 11.11: Settings gets a gear so it is not read as theme.
  settings(
    '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2.5"/><path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8"/>',
  ),
  chevronLeft('<path d="M15 5l-7 7 7 7"/>'),
  chevronRight('<path d="M9 5l7 7-7 7"/>'),
  arrowRight('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  play('<path d="M7 4.5v15l12.5-7.5z"/>', filled: true),
  check('<path d="M5 12.5l4.5 4.5L19 7"/>'),
  x('<path d="M6 6l12 12M18 6L6 18"/>'),
  plus('<path d="M12 5v14M5 12h14"/>'),
  minus('<path d="M6 12h12"/>'),
  thumbsUp(
    '<path d="M7 11v9H4v-9zM7 11l4-8c1.5 0 2.5 1 2 3l-.7 3H19a2 2 0 0 1 2 2.3l-1 6a2 2 0 0 1-2 1.7H7"/>',
  ),
  thumbsDown(
    '<path d="M7 13V4H4v9zM7 13l4 8c1.5 0 2.5-1 2-3l-.7-3H19a2 2 0 0 0 2-2.3l-1-6A2 2 0 0 0 18 4H7"/>',
  ),
  wifiOff(
    '<path d="M2 8.5a15 15 0 0 1 20 0M5.5 12a10 10 0 0 1 13 0M9 15.5a5 5 0 0 1 6 0M12 19h.01M3 3l18 18"/>',
  ),
  send('<path d="M4 12l16-8-6 16-3-7z"/>');

  const MxIcons(this.body, {this.filled = false});
  final String body;
  final bool filled;

  String svg(Color color, {double strokeWidth = 2}) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    final opacity = (color.a).toStringAsFixed(3);
    final paint = filled
        ? 'fill="#$hex" fill-opacity="$opacity" stroke="none"'
        : 'fill="none" stroke="#$hex" stroke-opacity="$opacity" '
              'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round"';
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" $paint>$body</svg>';
  }
}

class MxIcon extends StatelessWidget {
  const MxIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.semanticLabel,
  });

  final MxIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return SvgPicture.string(
      icon.svg(c, strokeWidth: strokeWidth),
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
