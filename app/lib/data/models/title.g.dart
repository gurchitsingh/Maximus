// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'title.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TitleSummary _$TitleSummaryFromJson(Map<String, dynamic> json) => TitleSummary(
  id: json['id'] as String,
  kind: json['kind'] as String,
  name: json['name'] as String,
  subtitle: json['subtitle'] as String?,
  posterLines: (json['poster_lines'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  group: json['group'] as String,
  era: json['era'] as String,
  region: json['region'] as String,
  periodStart: (json['period_start'] as num?)?.toInt(),
  periodEnd: (json['period_end'] as num?)?.toInt(),
  themes: (json['themes'] as List<dynamic>).map((e) => e as String).toList(),
  bg: json['bg'] as String,
  tint: json['tint'] as String,
  lettering: json['lettering'] as String,
  posterImageId: json['poster_image_id'] as String?,
  heroImageId: json['hero_image_id'] as String?,
  brief: json['brief'] as String,
  readingMinutes: (json['reading_minutes'] as num).toInt(),
  lessonCount: (json['lesson_count'] as num).toInt(),
  quizCount: (json['quiz_count'] as num).toInt(),
  linkedTitleIds:
      (json['linked_title_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  rank: (json['rank'] as num).toInt(),
  status: json['status'] as String,
  contentVersion: (json['content_version'] as num).toInt(),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
  id: json['id'] as String,
  titleId: json['title_id'] as String,
  index: (json['index'] as num).toInt(),
  heading: json['heading'] as String,
  body: json['body'] as String,
  readingMinutes: (json['reading_minutes'] as num).toInt(),
  imageIds:
      (json['image_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  readAloudText: json['read_aloud_text'] as String?,
  sourceIds:
      (json['source_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

ContentImage _$ContentImageFromJson(Map<String, dynamic> json) => ContentImage(
  id: json['id'] as String,
  titleId: json['title_id'] as String,
  url: json['url'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  alt: json['alt'] as String,
  kind: json['kind'] as String,
  author: json['author'] as String,
  license: json['license'] as String,
  licenseVersion: json['license_version'] as String?,
  licenseUrl: json['license_url'] as String?,
  sourcePageUrl: json['source_page_url'] as String?,
  creditLine: json['credit_line'] as String,
  modified: json['modified'] as bool? ?? false,
  focalX: (json['focal_x'] as num?)?.toDouble() ?? 0.5,
  focalY: (json['focal_y'] as num?)?.toDouble() ?? 0.5,
);

QuizQuestion _$QuizQuestionFromJson(Map<String, dynamic> json) => QuizQuestion(
  id: json['id'] as String,
  titleId: json['title_id'] as String,
  lessonId: json['lesson_id'] as String?,
  prompt: json['prompt'] as String,
  options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
  correctIndex: (json['correct_index'] as num).toInt(),
  explanation: json['explanation'] as String,
  difficulty: json['difficulty'] as String,
  status: json['status'] as String,
  reviewNote: json['review_note'] as String?,
);

FeedFact _$FeedFactFromJson(Map<String, dynamic> json) => FeedFact(
  id: json['id'] as String,
  titleId: json['title_id'] as String,
  lessonId: json['lesson_id'] as String?,
  text: json['text'] as String,
  imageId: json['image_id'] as String?,
  status: json['status'] as String,
  reviewNote: json['review_note'] as String?,
);

Source _$SourceFromJson(Map<String, dynamic> json) => Source(
  id: json['id'] as String,
  title: json['title'] as String,
  url: json['url'] as String,
  publisher: json['publisher'] as String?,
  role: json['role'] as String,
  license: json['license'] as String?,
  confidence: json['confidence'] as String?,
);

Person _$PersonFromJson(Map<String, dynamic> json) => Person(
  role: json['role'] as String,
  born: PersonDate.fromJson(json['born'] as Map<String, dynamic>),
  died: json['died'] == null
      ? null
      : PersonDate.fromJson(json['died'] as Map<String, dynamic>),
  region: json['region'] as String,
  headline: json['headline'] as String,
  traits:
      (json['traits'] as List<dynamic>?)
          ?.map((e) => NamedClaim.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  changes:
      (json['changes'] as List<dynamic>?)
          ?.map((e) => Claim.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  oddsBeaten:
      (json['odds_beaten'] as List<dynamic>?)
          ?.map((e) => OddsBeaten.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  coreIdeas:
      (json['core_ideas'] as List<dynamic>?)
          ?.map((e) => NamedClaim.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  useToday:
      (json['use_today'] as List<dynamic>?)
          ?.map((e) => Claim.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  legendNote: json['legend_note'] as String?,
);

PersonDate _$PersonDateFromJson(Map<String, dynamic> json) => PersonDate(
  year: (json['year'] as num?)?.toInt(),
  display: json['display'] as String,
);

Claim _$ClaimFromJson(Map<String, dynamic> json) => Claim(
  text: json['text'] as String,
  sourceIds:
      (json['source_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

NamedClaim _$NamedClaimFromJson(Map<String, dynamic> json) => NamedClaim(
  name: json['name'] as String,
  text: json['text'] as String,
  sourceIds:
      (json['source_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

OddsBeaten _$OddsBeatenFromJson(Map<String, dynamic> json) => OddsBeaten(
  event: json['event'] as String,
  yearDisplay: json['year_display'] as String,
  whyImpossible: json['why_impossible'] as String,
  outcome: json['outcome'] as String,
  outcomeKind: json['outcome_kind'] as String,
  sourceIds:
      (json['source_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);
