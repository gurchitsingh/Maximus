// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalogue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Catalogue _$CatalogueFromJson(Map<String, dynamic> json) => Catalogue(
  catalogueVersion: json['catalogue_version'] as String,
  generatedAt: DateTime.parse(json['generated_at'] as String),
  featuredId: json['featured_id'] as String?,
  peopleRowLabel: json['people_row_label'] as String,
  onboardingLeaderIds:
      (json['onboarding_leader_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  groups: (json['groups'] as List<dynamic>)
      .map((e) => CatalogueGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
  titles: (json['titles'] as List<dynamic>)
      .map((e) => TitleSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  images:
      (json['images'] as List<dynamic>?)
          ?.map((e) => ContentImage.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

CatalogueGroup _$CatalogueGroupFromJson(Map<String, dynamic> json) =>
    CatalogueGroup(
      key: json['key'] as String,
      label: json['label'] as String,
      people: json['people'] as bool,
      order: (json['order'] as num).toInt(),
    );
