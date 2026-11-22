// JSON models for docs/schemas/title.schema.json (CONTRACTS 2). Tolerant
// readers (P7): unknown fields are ignored, so additive server changes need
// no app release.
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'title.g.dart';

/// Catalogue item = the summary fields of a title (2.1).
@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class TitleSummary {
  const TitleSummary({
    required this.id,
    required this.kind,
    required this.name,
    this.subtitle,
    required this.posterLines,
    required this.group,
    required this.era,
    required this.region,
    this.periodStart,
    this.periodEnd,
    required this.themes,
    required this.bg,
    required this.tint,
    required this.lettering,
    this.posterImageId,
    this.heroImageId,
    required this.brief,
    required this.readingMinutes,
    required this.lessonCount,
    required this.quizCount,
    this.linkedTitleIds = const [],
    required this.rank,
    required this.status,
    required this.contentVersion,
    required this.updatedAt,
  });

  factory TitleSummary.fromJson(Map<String, dynamic> json) =>
      _$TitleSummaryFromJson(json);

  final String id;

  /// `topic` | `leader` | `thinker`.
  final String kind;
  final String name;
  final String? subtitle;
  final List<String> posterLines;
  final String group;
  final String era;
  final String region;
  final int? periodStart;
  final int? periodEnd;
  final List<String> themes;

  /// `#RRGGBB`. Data, not theme.
  final String bg;
  final String tint;

  /// `roman` | `brush` | `stencil` | `carved`.
  final String lettering;
  final String? posterImageId;
  final String? heroImageId;
  final String brief;
  final int readingMinutes;
  final int lessonCount;
  final int quizCount;
  final List<String> linkedTitleIds;
  final int rank;
  final String status;
  final int contentVersion;
  final DateTime updatedAt;

  bool get isPerson => kind != 'topic';
}

/// GET /v1/titles/{id}: summary fields + detail fields, one flat object.
@immutable
class TitleDetail {
  const TitleDetail({
    required this.summary,
    required this.lessons,
    required this.images,
    required this.quiz,
    required this.feedFacts,
    required this.person,
    required this.sources,
  });

  factory TitleDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [
      for (final x in (json[k] as List? ?? const []))
        f(x as Map<String, dynamic>),
    ];
    final lessons = list('lessons', Lesson.fromJson)
      ..sort((a, b) => a.index.compareTo(b.index));
    return TitleDetail(
      summary: TitleSummary.fromJson(json),
      lessons: lessons,
      images: list('images', ContentImage.fromJson),
      quiz: list('quiz', QuizQuestion.fromJson),
      feedFacts: list('feed_facts', FeedFact.fromJson),
      person: json['person'] == null
          ? null
          : Person.fromJson(json['person'] as Map<String, dynamic>),
      sources: list('sources', Source.fromJson),
    );
  }

  final TitleSummary summary;

  /// Ordered by `index` 1..n.
  final List<Lesson> lessons;
  final List<ContentImage> images;
  final List<QuizQuestion> quiz;
  final List<FeedFact> feedFacts;
  final Person? person;
  final List<Source> sources;

  String get id => summary.id;

  ContentImage? image(String? id) {
    if (id == null) return null;
    for (final i in images) {
      if (i.id == id) return i;
    }
    return null;
  }

  Source? source(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  Lesson? lesson(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Lesson {
  const Lesson({
    required this.id,
    required this.titleId,
    required this.index,
    required this.heading,
    required this.body,
    required this.readingMinutes,
    this.imageIds = const [],
    this.readAloudText,
    this.sourceIds = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);

  final String id;
  final String titleId;
  final int index;
  final String heading;

  /// Markdown subset (2.2), parsed by domain/markdown_lite.
  final String body;
  final int readingMinutes;

  /// `[0]` is the hero above the heading.
  final List<String> imageIds;
  final String? readAloudText;
  final List<String> sourceIds;
}

/// An image and its licence fields (2.3).
@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ContentImage {
  const ContentImage({
    required this.id,
    required this.titleId,
    required this.url,
    required this.width,
    required this.height,
    required this.alt,
    required this.kind,
    required this.author,
    required this.license,
    this.licenseVersion,
    this.licenseUrl,
    this.sourcePageUrl,
    required this.creditLine,
    this.modified = false,
    this.focalX = 0.5,
    this.focalY = 0.5,
  });

  factory ContentImage.fromJson(Map<String, dynamic> json) =>
      _$ContentImageFromJson(json);

  final String id;
  final String titleId;
  final String url;
  final int width;
  final int height;
  final String alt;
  final String kind;
  final String author;

  /// `PD` | `CC0` | `CC BY` | `CC BY-SA` | `OWN`.
  final String license;
  final String? licenseVersion;
  final String? licenseUrl;
  final String? sourcePageUrl;
  final String creditLine;
  final bool modified;
  final double focalX;
  final double focalY;

  double get aspectRatio => width / height;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.titleId,
    this.lessonId,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.difficulty,
    required this.status,
    this.reviewNote,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) =>
      _$QuizQuestionFromJson(json);

  final String id;
  final String titleId;
  final String? lessonId;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;
  final String status;
  final String? reviewNote;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class FeedFact {
  const FeedFact({
    required this.id,
    required this.titleId,
    this.lessonId,
    required this.text,
    this.imageId,
    required this.status,
    this.reviewNote,
  });

  factory FeedFact.fromJson(Map<String, dynamic> json) =>
      _$FeedFactFromJson(json);

  final String id;
  final String titleId;
  final String? lessonId;
  final String text;
  final String? imageId;
  final String status;
  final String? reviewNote;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Source {
  const Source({
    required this.id,
    required this.title,
    required this.url,
    this.publisher,
    required this.role,
    this.license,
    this.confidence,
  });

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);

  final String id;
  final String title;
  final String url;
  final String? publisher;

  /// `text` (lesson text adapted from it) | `citation`.
  final String role;
  final String? license;
  final String? confidence;
}

/// Leader and thinker fields (2.4). Rendered by the person sheet (S5).
@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Person {
  const Person({
    required this.role,
    required this.born,
    this.died,
    required this.region,
    required this.headline,
    this.traits = const [],
    this.changes = const [],
    this.oddsBeaten = const [],
    this.coreIdeas = const [],
    this.useToday = const [],
    this.legendNote,
  });

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);

  final String role;
  final PersonDate born;
  final PersonDate? died;
  final String region;
  final String headline;
  final List<NamedClaim> traits;
  final List<Claim> changes;
  final List<OddsBeaten> oddsBeaten;
  final List<NamedClaim> coreIdeas;
  final List<Claim> useToday;
  final String? legendNote;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class PersonDate {
  const PersonDate({this.year, required this.display});
  factory PersonDate.fromJson(Map<String, dynamic> json) =>
      _$PersonDateFromJson(json);

  final int? year;
  final String display;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Claim {
  const Claim({required this.text, this.sourceIds = const []});
  factory Claim.fromJson(Map<String, dynamic> json) => _$ClaimFromJson(json);

  final String text;
  final List<String> sourceIds;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class NamedClaim {
  const NamedClaim({
    required this.name,
    required this.text,
    this.sourceIds = const [],
  });
  factory NamedClaim.fromJson(Map<String, dynamic> json) =>
      _$NamedClaimFromJson(json);

  final String name;
  final String text;
  final List<String> sourceIds;
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class OddsBeaten {
  const OddsBeaten({
    required this.event,
    required this.yearDisplay,
    required this.whyImpossible,
    required this.outcome,
    required this.outcomeKind,
    this.sourceIds = const [],
  });
  factory OddsBeaten.fromJson(Map<String, dynamic> json) =>
      _$OddsBeatenFromJson(json);

  final String event;
  final String yearDisplay;
  final String whyImpossible;
  final String outcome;
  final String outcomeKind;
  final List<String> sourceIds;
}
