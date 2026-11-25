// Bundled SVG poster art (CONTRACTS 21). Light theme shows day, dark shows
// evening. Modes come from assets/posters/manifest.json:
//   pair   <id>.day.svg / <id>.evening.svg, no overlay
//   wash   <id>.svg plus a theme overlay
//   single <id>.svg, unchanged
// A title with no poster, or whose file is missing, draws a flat tile from the
// manifest bg and tint (or the caller's fallback colours).
import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// App-side crops of the 200 x 300 artboard (DESIGN_SPEC 8.1).
enum PosterCrop {
  poster(0, 0, 200, 300),
  banner(0, 50, 200, 100),
  square(20, 40, 160, 160);

  const PosterCrop(this.x, this.y, this.width, this.height);
  final double x;
  final double y;
  final double width;
  final double height;

  double get aspectRatio => width / height;
}

enum PosterMode { pair, wash, single }

@immutable
class PosterEntry {
  const PosterEntry({
    required this.mode,
    required this.bg,
    required this.tint,
    this.lettering,
    this.lines = const [],
  });

  final PosterMode mode;
  final Color bg;
  final Color tint;
  final String? lettering;
  final List<String> lines;
}

Color _hex(String s) =>
    Color(0xFF000000 | int.parse(s.replaceFirst('#', ''), radix: 16));

/// Parsed `assets/posters/manifest.json`.
class PosterManifest {
  PosterManifest(this.entries);

  final Map<String, PosterEntry> entries;

  PosterEntry? operator [](String titleId) => entries[titleId];

  static const assetPath = 'assets/posters/manifest.json';

  factory PosterManifest.parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return PosterManifest({
      for (final e in raw.entries)
        e.key: () {
          final m = e.value as Map<String, dynamic>;
          return PosterEntry(
            mode: PosterMode.values.byName(m['mode'] as String),
            bg: _hex(m['bg'] as String),
            tint: _hex(m['tint'] as String),
            lettering: m['lettering'] as String?,
            lines: [
              for (final l in (m['lines'] as List<dynamic>? ?? const []))
                l as String,
            ],
          );
        }(),
    });
  }

  static final Map<AssetBundle, Future<PosterManifest>> _cache = {};

  static Future<PosterManifest> load(AssetBundle bundle) => _cache.putIfAbsent(
    bundle,
    () => bundle.loadString(assetPath).then(PosterManifest.parse),
  );
}

class BundledPosterArt extends StatelessWidget {
  const BundledPosterArt({
    super.key,
    required this.titleId,
    this.crop = PosterCrop.poster,
    this.brightness,
    this.fallbackBg,
    this.fallbackTint,
    this.manifest,
  });

  final String titleId;
  final PosterCrop crop;

  /// Defaults to the ambient theme: light shows day, dark shows evening.
  final Brightness? brightness;

  /// Used when the title has no manifest entry.
  final Color? fallbackBg;
  final Color? fallbackTint;

  /// Preloaded manifest; when null it is read from the ambient asset bundle.
  final PosterManifest? manifest;

  static const _washDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromRGBO(48, 24, 88, .34),
      Color.fromRGBO(238, 118, 44, .16),
    ],
  );
  static const _washLight = RadialGradient(
    center: Alignment(.64, -.72), // 82% / 14% of the box
    radius: .58,
    colors: [Color.fromRGBO(255, 240, 180, .6), Color(0x00FFF0B4)],
  );

  @override
  Widget build(BuildContext context) {
    final m = manifest;
    if (m != null) return _build(context, m);
    return FutureBuilder<PosterManifest>(
      future: PosterManifest.load(DefaultAssetBundle.of(context)),
      builder: (context, snap) {
        final loaded = snap.data;
        if (loaded == null) return _tile(context, null);
        return _build(context, loaded);
      },
    );
  }

  Widget _build(BuildContext context, PosterManifest m) {
    final entry = m[titleId];
    if (entry == null) return _tile(context, null);
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    final asset = switch (entry.mode) {
      PosterMode.pair =>
        'assets/posters/$titleId.${dark ? 'evening' : 'day'}.svg',
      _ => 'assets/posters/$titleId.svg',
    };
    final overlay = entry.mode == PosterMode.wash
        ? DecoratedBox(
            decoration: BoxDecoration(gradient: dark ? _washDark : _washLight),
          )
        : null;
    return AspectRatio(
      aspectRatio: crop.aspectRatio,
      child: LayoutBuilder(
        builder: (context, c) {
          final scale = c.maxWidth / crop.width;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -crop.x * scale,
                  top: -crop.y * scale,
                  width: 200 * scale,
                  height: 300 * scale,
                  child: SvgPicture.asset(
                    asset,
                    bundle: DefaultAssetBundle.of(context),
                    fit: BoxFit.fill,
                    placeholderBuilder: (_) => _fill(entry.bg),
                    errorBuilder: (context, _, _) => _tileBody(entry),
                  ),
                ),
                ?overlay,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, PosterEntry? entry) {
    return AspectRatio(aspectRatio: crop.aspectRatio, child: _tileBody(entry));
  }

  Widget _fill(Color c) => ColoredBox(color: c);

  Widget _tileBody(PosterEntry? entry) {
    final bg = entry?.bg ?? fallbackBg ?? const Color(0xFF2A2A33);
    final tint = entry?.tint ?? fallbackTint ?? const Color(0xFF8A8AA0);
    return DecoratedBox(
      key: const ValueKey('poster-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(tint.withValues(alpha: .35), bg), bg],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
