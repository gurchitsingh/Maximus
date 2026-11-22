// Per-title colour helpers. `bg` and `tint` are data from the payload
// (CONTRACTS 8.1), never theme constants.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// `#RRGGBB` -> Color. Bad input falls back to [fallback].
Color hexColor(String hex, {Color fallback = const Color(0xFF262017)}) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
  return v == null ? fallback : Color(0xFF000000 | v);
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The tint as text on [background] (kickers, DESIGN_SPEC 11.9): darkened
/// (light themes) or lightened (dark) in HSL steps until it reaches 4.5:1.
/// Art keeps the raw tint; only tint-coloured text uses this.
Color readableTint(Color tint, Color background, {double target = 4.5}) {
  if (contrastRatio(tint, background) >= target) return tint;
  final darken = background.computeLuminance() > 0.5;
  var hsl = HSLColor.fromColor(tint);
  for (var i = 0; i < 40; i++) {
    final l = (hsl.lightness + (darken ? -0.025 : 0.025)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(l);
    final c = hsl.toColor();
    if (contrastRatio(c, background) >= target || l == 0 || l == 1) return c;
  }
  return hsl.toColor();
}
