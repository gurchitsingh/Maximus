// Title data -> shared widget data, and the navigation every feature uses
// to open a title sheet or the reader.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/util/colors.dart';
import '../../core/util/image_cache.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/catalogue.dart';
import '../../data/models/title.dart';
import '../../data/providers.dart';

/// The sample payloads point at placeholder files on example.org/com that
/// do not exist ("SAMPLE placeholder (not a real file)"). Skip them so the
/// dev build makes no network calls and shows the tinted gradient instead.
String? imageUrl(ContentImage? image) {
  if (image == null) return null;
  if (isPlaceholderImageUrl(image.url)) return null;
  return image.url;
}

PosterData posterData(TitleSummary t, Catalogue c) => PosterData(
  lines: t.posterLines,
  lettering: MxLettering.parse(t.lettering),
  bg: hexColor(t.bg),
  tint: hexColor(t.tint),
  imageUrl: imageUrl(c.image(t.posterImageId)),
  titleId: t.id,
);

/// Wide art (sheet banner, hero, resume card, thumbs): hero image, else the
/// poster cropped by its focal point, else the tinted gradient (2.1).
/// With [crop], a bundled poster (CONTRACTS 21) wins when the title has one.
ArtData titleArt(
  TitleSummary t,
  ContentImage? Function(String?) image, {
  PosterCrop? crop,
}) {
  final img = image(t.heroImageId) ?? image(t.posterImageId);
  return ArtData(
    bg: hexColor(t.bg),
    tint: hexColor(t.tint),
    imageUrl: imageUrl(img),
    focalX: img?.focalX ?? 0.5,
    focalY: img?.focalY ?? 0.5,
    titleId: t.id,
    crop: crop,
  );
}

ArtData imageArt(TitleSummary t, ContentImage? img) => ArtData(
  bg: hexColor(t.bg),
  tint: hexColor(t.tint),
  imageUrl: imageUrl(img),
  focalX: img?.focalX ?? 0.5,
  focalY: img?.focalY ?? 0.5,
  alt: img?.alt,
);

String lessonsMeta(TitleSummary t) =>
    '${t.lessonCount} ${t.lessonCount == 1 ? 'lesson' : 'lessons'} · '
    '${t.readingMinutes} min';

void openTitleSheet(BuildContext context, String titleId) =>
    context.push(AppRoute.titleSheet.location({'titleId': titleId}));

/// Opens the reader at the resume lesson (FLOW 5): the next unfinished
/// lesson after the last one opened, or lesson 1. [replace] swaps the top
/// page (used from the title sheet so Back skips the sheet).
Future<void> openReader(
  BuildContext context,
  WidgetRef ref,
  String titleId, {
  bool closeSheetFirst = false,

  /// "Read again": open lesson 1 instead of the resume lesson.
  bool fromStart = false,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final detail = await ref.read(titleDetailProvider(titleId).future);
    if (detail.lessons.isEmpty) return;
    final lesson = fromStart
        ? detail.lessons.first
        : ref.read(titleProgressProvider(titleId)).resumeLesson(detail.lessons);
    if (closeSheetFirst && router.canPop()) router.pop();
    router.push(
      AppRoute.reader.location({'titleId': titleId, 'lessonId': lesson.id}),
    );
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('This title needs a connection the first time.'),
      ),
    );
  }
}
