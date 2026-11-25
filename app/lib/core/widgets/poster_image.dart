// One entry point for title poster art (CONTRACTS 21, D54). A title with a
// manifest entry draws its bundled SVG (BundledPosterArt, theme-aware: dark
// shows evening, light shows day) cropped to [crop]; any other title draws
// [fallback], the network image or tinted gradient the screen used before.
import 'package:material_ui/material_ui.dart';

import 'poster_art.dart';

class PosterImage extends StatefulWidget {
  const PosterImage({
    super.key,
    required this.titleId,
    required this.fallback,
    this.crop = PosterCrop.poster,
    this.manifest,
  });

  /// Null means the caller has no catalogue id: [fallback] is shown.
  final String? titleId;
  final PosterCrop crop;

  /// Shown when the title has no bundled poster, and while the manifest loads.
  final Widget fallback;

  /// Preloaded manifest (tests); when null it comes from the asset bundle.
  final PosterManifest? manifest;

  @override
  State<PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<PosterImage> {
  static final Map<AssetBundle, PosterManifest> _ready = {};
  Future<PosterManifest>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (widget.manifest == null && !_ready.containsKey(bundle)) {
      _future = PosterManifest.load(bundle)
          .then((m) => _ready[bundle] = m)
          .catchError((_) => PosterManifest({}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.titleId;
    if (id == null) return widget.fallback;
    final m = widget.manifest ?? _ready[DefaultAssetBundle.of(context)];
    if (m != null) return _art(id, m);
    return FutureBuilder<PosterManifest>(
      future: _future,
      builder: (context, snap) {
        final loaded = snap.data;
        return loaded == null ? widget.fallback : _art(id, loaded);
      },
    );
  }

  Widget _art(String id, PosterManifest m) {
    if (m[id] == null) return widget.fallback;
    final crop = widget.crop;
    // Fill the parent like BoxFit.cover: the crop keeps its aspect ratio and
    // the overflow is clipped.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: crop.width,
          height: crop.height,
          child: BundledPosterArt(titleId: id, crop: crop, manifest: m),
        ),
      ),
    );
  }
}
