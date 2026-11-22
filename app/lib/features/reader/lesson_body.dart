// Renders a lesson body (markdown_lite blocks), images with credit captions
// and the CC BY-SA attribution line (CONTRACTS 2.2, 2.8).
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/title.dart';
import '../../domain/markdown_lite.dart';
import '../shared/title_visuals.dart';

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class LessonBody extends StatelessWidget {
  const LessonBody({super.key, required this.detail, required this.lesson});

  final TitleDetail detail;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final para = Theme.of(context)
        .extension<MxReading>()!
        .paragraph
        .copyWith(color: c.text);
    final blocks = parseMarkdownLite(lesson.body);
    final placed = {for (final b in blocks.whereType<MdImage>()) b.imageId};
    final unplaced = lesson.imageIds.skip(1).where((i) => !placed.contains(i));

    TextSpan rich(List<MdSpan> s, TextStyle base) => TextSpan(
      style: base,
      children: [
        for (final x in s)
          TextSpan(
            text: x.text,
            style: TextStyle(
              fontWeight: x.bold ? FontWeight.w800 : null,
              fontStyle: x.italic ? FontStyle.italic : null,
            ),
          ),
      ],
    );

    Widget image(String id) {
      final img = detail.image(id);
      if (img == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LessonImage(detail: detail, image: img),
      );
    }

    final children = <Widget>[];
    for (final b in blocks) {
      switch (b) {
        case MdParagraph(:final spans):
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: MxReading.paragraphGap),
              child: Text.rich(rich(spans, para)),
            ),
          );
        case MdHeading(spans: final s):
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Semantics(
                header: true,
                child: Text.rich(
                  rich(s, MxText.readerHeading.copyWith(color: c.text)),
                ),
              ),
            ),
          );
        case MdBullets(:final items):
          for (final item in items) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Text('•  ', style: para)),
                    Expanded(child: Text.rich(rich(item, para))),
                  ],
                ),
              ),
            );
          }
          children.add(const SizedBox(height: MxReading.paragraphGap - 6));
        case MdQuote(spans: final s):
          children.add(
            Container(
              margin: const EdgeInsets.only(bottom: MxReading.paragraphGap),
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.accentText, width: 3)),
              ),
              child: Text.rich(
                rich(s, para.copyWith(fontStyle: FontStyle.italic)),
              ),
            ),
          );
        case MdImage(:final imageId):
          children.add(image(imageId));
      }
    }
    children.addAll(unplaced.map(image));

    final textSources = [
      for (final id in lesson.sourceIds)
        if (detail.source(id) case final s? when s.role == 'text') s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        for (final s in textSources)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Attribution(source: s),
          ),
      ],
    );
  }
}

/// "Text adapted from {source}, CC BY-SA 4.0. Shortened." with the link.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.source});
  final Source source;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final licence = source.license ?? 'CC BY-SA 4.0';
    return Semantics(
      link: true,
      label:
          'Text adapted from ${source.title}, $licence. Shortened. Opens the source.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openExternal(source.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(
            TextSpan(
              style: MxText.caption.copyWith(color: c.textMuted),
              children: [
                const TextSpan(text: 'Text adapted from '),
                TextSpan(
                  text: source.title,
                  style: TextStyle(
                    color: c.accentText,
                    decoration: TextDecoration.underline,
                    decorationColor: c.accentText,
                  ),
                ),
                TextSpan(text: ', $licence. Shortened.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An image with its credit caption under it (CONTRACTS 2.8). Tapping the
/// caption opens the image details.
class LessonImage extends StatelessWidget {
  const LessonImage({
    super.key,
    required this.detail,
    required this.image,
    this.height,
  });

  final TitleDetail detail;
  final ContentImage image;

  /// Fixed height (reader hero 210); null = the image's own aspect ratio.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final art = TitleArt(data: imageArt(detail.summary, image));
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(MxRadius.card),
      child: height == null
          ? AspectRatio(aspectRatio: image.aspectRatio, child: art)
          : SizedBox(height: height, width: double.infinity, child: art),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box,
        CreditCaption(image: image),
      ],
    );
  }
}

class CreditCaption extends StatelessWidget {
  const CreditCaption({super.key, required this.image});
  final ContentImage image;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      label: 'Image credit: ${image.creditLine}. Show details.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showImageDetails(context, image),
        child: ConstrainedBox(
          // Keep the tap target at 48 dp even for a one-line caption.
          constraints: const BoxConstraints(minHeight: MxSpace.minTouch),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                image.creditLine,
                style: MxText.caption.copyWith(color: c.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showImageDetails(BuildContext context, ContentImage image) {
  final licence = [
    image.license,
    if (image.licenseVersion != null) image.licenseVersion!,
  ].join(' ');
  return showMxBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final c = ctx.mx;
      Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 4),
            Text(value, style: MxText.body.copyWith(color: c.text)),
          ],
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Image credit',
            style: MxText.emptyTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 16),
          row('About', image.alt),
          row('By', image.author),
          row('Licence', licence),
          if (image.modified) row('Changes', 'Cropped or resized for the app.'),
          if (image.sourcePageUrl != null) ...[
            const SizedBox(height: 4),
            SecondaryButton(
              label: 'Open the source page',
              icon: MxIcons.arrowRight,
              onPressed: () => openExternal(image.sourcePageUrl!),
            ),
          ],
          if (image.licenseUrl != null) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Read the licence',
              icon: MxIcons.arrowRight,
              onPressed: () => openExternal(image.licenseUrl!),
            ),
          ],
        ],
      );
    },
  );
}
