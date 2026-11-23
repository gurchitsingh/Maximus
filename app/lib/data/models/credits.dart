// GET /v1/credits (docs/schemas/credits.schema.json, CONTRACTS 2.8) and the
// bundled font list (assets/credits/fonts.json). Plain Dart, no codegen.
import 'package:meta/meta.dart';

@immutable
class FontCredit {
  const FontCredit({
    required this.family,
    required this.designer,
    required this.weights,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
  });

  factory FontCredit.fromJson(Map<String, dynamic> j) => FontCredit(
    family: j['family'] as String,
    designer: j['designer'] as String,
    weights: [for (final w in j['weights'] as List) w as int],
    license: j['license'] as String,
    licenseUrl: j['license_url'] as String,
    sourceUrl: j['source_url'] as String,
  );

  final String family;
  final String designer;
  final List<int> weights;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
}

@immutable
class TextSourceCredit {
  const TextSourceCredit({
    required this.titleId,
    required this.titleName,
    required this.name,
    required this.url,
    required this.license,
  });

  factory TextSourceCredit.fromJson(Map<String, dynamic> j) => TextSourceCredit(
    titleId: j['title_id'] as String,
    titleName: j['title_name'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    license: j['license'] as String,
  );

  final String titleId;
  final String titleName;
  final String name;
  final String url;
  final String license;
}

@immutable
class ImageCredit {
  const ImageCredit({
    required this.imageId,
    required this.titleId,
    required this.titleName,
    required this.creditLine,
    required this.license,
    this.licenseUrl,
    this.sourcePageUrl,
    required this.modified,
  });

  factory ImageCredit.fromJson(Map<String, dynamic> j) => ImageCredit(
    imageId: j['image_id'] as String,
    titleId: j['title_id'] as String,
    titleName: j['title_name'] as String,
    creditLine: j['credit_line'] as String,
    license: j['license'] as String,
    licenseUrl: j['license_url'] as String?,
    sourcePageUrl: j['source_page_url'] as String?,
    modified: j['modified'] as bool,
  );

  final String imageId;
  final String titleId;
  final String titleName;
  final String creditLine;
  final String license;
  final String? licenseUrl;
  final String? sourcePageUrl;
  final bool modified;
}

/// The server part of the Credits screen.
@immutable
class ContentCredits {
  const ContentCredits({
    required this.notices,
    required this.textSources,
    required this.images,
  });

  factory ContentCredits.fromJson(Map<String, dynamic> j) => ContentCredits(
    notices: [for (final n in j['notices'] as List) n as String],
    textSources: [
      for (final s in j['text_sources'] as List)
        TextSourceCredit.fromJson(s as Map<String, dynamic>),
    ],
    images: [
      for (final i in j['images'] as List)
        ImageCredit.fromJson(i as Map<String, dynamic>),
    ],
  );

  final List<String> notices;
  final List<TextSourceCredit> textSources;
  final List<ImageCredit> images;

  /// Title ids in the order the server sent them (rank, id), first seen.
  List<({String id, String name})> get titles {
    final seen = <String>{};
    return [
      for (final t in [
        for (final s in textSources) (id: s.titleId, name: s.titleName),
        for (final i in images) (id: i.titleId, name: i.titleName),
      ])
        if (seen.add(t.id)) t,
    ];
  }
}
