// Title artwork cropped by its focal point (CONTRACTS 2.3 focal_x/focal_y):
// sheet banner, hero banner, resume card, thumbnails, reader hero. No image
// or a failed load = the tinted gradient (DESIGN_SPEC 12.4, CONTRACTS 3.6).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../util/image_cache.dart';
import 'poster_art.dart';
import 'poster_card.dart';
import 'poster_image.dart';

@immutable
class ArtData {
  const ArtData({
    required this.bg,
    required this.tint,
    this.imageUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.alt,
    this.titleId,
    this.crop,
  });

  final Color bg;
  final Color tint;
  final String? imageUrl;
  final double focalX;
  final double focalY;

  /// Screen-reader text of the image, when it is content (reader hero).
  final String? alt;

  /// With [crop], a bundled poster for this title replaces the image. Left
  /// null where the art is a content photo (reader, feed, quiz).
  final String? titleId;
  final PosterCrop? crop;
}

class TitleArt extends StatelessWidget {
  const TitleArt({super.key, required this.data});

  final ArtData data;

  @override
  Widget build(BuildContext context) {
    final fallback = TintedGradient(bg: data.bg, tint: data.tint);
    final url = data.imageUrl;
    Widget art = url == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            cacheManager: mxImageCache,
            fit: BoxFit.cover,
            alignment: Alignment(data.focalX * 2 - 1, data.focalY * 2 - 1),
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
            fadeInDuration: MxMotion.fade,
          );
    final crop = data.crop;
    if (crop != null) {
      art = PosterImage(titleId: data.titleId, crop: crop, fallback: art);
    }
    art = ColoredBox(color: data.bg, child: art);
    return data.alt == null
        ? ExcludeSemantics(child: art)
        : Semantics(
            image: true,
            label: data.alt,
            child: ExcludeSemantics(child: art),
          );
  }
}

/// Bottom-up image scrim: rgba(10,8,5,[alpha]) from [from] to 0 at [to].
class ArtScrim extends StatelessWidget {
  const ArtScrim({
    super.key,
    required this.alpha,
    required this.from,
    required this.to,
  });

  final double alpha;
  final double from;
  final double to;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            MxFixed.scrimA(alpha),
            MxFixed.scrimA(alpha),
            MxFixed.scrimA(0),
          ],
          stops: [0, from, to],
        ),
      ),
    );
  }
}
