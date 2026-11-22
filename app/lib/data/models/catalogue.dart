// GET /v1/catalogue (docs/schemas/catalogue.schema.json, CONTRACTS 3.2).
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'title.dart';

part 'catalogue.g.dart';

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Catalogue {
  const Catalogue({
    required this.catalogueVersion,
    required this.generatedAt,
    this.featuredId,
    required this.peopleRowLabel,
    this.onboardingLeaderIds = const [],
    required this.groups,
    required this.titles,
    this.images = const [],
  });

  factory Catalogue.fromJson(Map<String, dynamic> json) {
    final c = _$CatalogueFromJson(json);
    return Catalogue(
      catalogueVersion: c.catalogueVersion,
      generatedAt: c.generatedAt,
      featuredId: c.featuredId,
      peopleRowLabel: c.peopleRowLabel,
      onboardingLeaderIds: c.onboardingLeaderIds,
      groups: [...c.groups]..sort((a, b) => a.order.compareTo(b.order)),
      titles: [...c.titles]
        ..sort(
          (a, b) => a.rank != b.rank
              ? a.rank.compareTo(b.rank)
              : a.id.compareTo(b.id),
        ),
      images: c.images,
    );
  }

  final String catalogueVersion;
  final DateTime generatedAt;
  final String? featuredId;
  final String peopleRowLabel;
  final List<String> onboardingLeaderIds;

  /// Sorted by `order`.
  final List<CatalogueGroup> groups;

  /// Sorted by (rank, id).
  final List<TitleSummary> titles;

  /// Poster and hero images of the titles.
  final List<ContentImage> images;

  TitleSummary? title(String id) {
    for (final t in titles) {
      if (t.id == id) return t;
    }
    return null;
  }

  ContentImage? image(String? id) {
    if (id == null) return null;
    for (final i in images) {
      if (i.id == id) return i;
    }
    return null;
  }

  CatalogueGroup? group(String key) {
    for (final g in groups) {
      if (g.key == key) return g;
    }
    return null;
  }
}

@immutable
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class CatalogueGroup {
  const CatalogueGroup({
    required this.key,
    required this.label,
    required this.people,
    required this.order,
  });

  factory CatalogueGroup.fromJson(Map<String, dynamic> json) =>
      _$CatalogueGroupFromJson(json);

  final String key;
  final String label;
  final bool people;
  final int order;
}
