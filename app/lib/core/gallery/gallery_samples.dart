// Visual samples for the gallery only. Colours and lettering kinds are the
// design reference values (DESIGN_SPEC 8.1); real data arrives in S6/S12.
import 'package:material_ui/material_ui.dart';

import '../widgets/poster_card.dart';
import '../widgets/title_lettering.dart';

abstract final class GallerySamples {
  static const roman = PosterData(
    lines: ['ROMAN', 'HISTORY'],
    lettering: MxLettering.roman,
    bg: Color(0xFF2B0E0C),
    tint: Color(0xFFE8553A),
  );
  static const french = PosterData(
    lines: ['The French', 'Revolution'],
    lettering: MxLettering.brush,
    bg: Color(0xFFE9D9B2),
    tint: Color(0xFF6C8CFF),
  );
  static const ww2 = PosterData(
    lines: ['WORLD', 'WAR II'],
    lettering: MxLettering.stencil,
    bg: Color(0xFF1B261F),
    tint: Color(0xFFB8C25A),
  );
  static const egypt = PosterData(
    lines: ['ANCIENT', 'EGYPT'],
    lettering: MxLettering.carved,
    bg: Color(0xFFF0B35A),
    tint: Color(0xFFE8A33D),
  );

  /// A real TOPICS.md title with no design stand-in, one line only.
  static const space = PosterData(
    lines: ['SPACE', 'HISTORY'],
    lettering: MxLettering.carved,
    bg: Color(0xFF14213D),
    tint: Color(0xFF8FD3F0),
  );

  /// One-line title (second line blank), as Napoleon in the design.
  static const napoleon = PosterData(
    lines: ['Napoleon', ''],
    lettering: MxLettering.brush,
    bg: Color(0xFF1F2A44),
    tint: Color(0xFFE2B65A),
  );

  static const all = [roman, french, ww2, egypt, space, napoleon];
}
