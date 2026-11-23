// GET /v1/on-this-day (CONTRACTS 2.7). Tolerant reader (P7).
import 'package:meta/meta.dart';

@immutable
class OnThisDayItem {
  const OnThisDayItem({
    required this.year,
    required this.text,
    required this.pageTitle,
    this.linkedTitleId,
  });

  factory OnThisDayItem.fromJson(Map<String, dynamic> json) => OnThisDayItem(
    year: json['year'] as int,
    text: json['text'] as String,
    pageTitle: json['page_title'] as String,
    linkedTitleId: json['linked_title_id'] as String?,
  );

  /// Negative = BCE.
  final int year;
  final String text;
  final String pageTitle;
  final String? linkedTitleId;

  /// `1783 · Phonograph`, or `44 BCE · Roman Republic`.
  String get titleLine =>
      '${year < 0 ? '${-year} BCE' : '$year'} · $pageTitle';
}

@immutable
class OnThisDay {
  const OnThisDay({
    required this.date,
    required this.items,
    required this.sourceName,
    required this.license,
  });

  factory OnThisDay.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as Map<String, dynamic>;
    return OnThisDay(
      date: json['date'] as String,
      items: [
        for (final x in json['items'] as List)
          OnThisDayItem.fromJson(x as Map<String, dynamic>),
      ],
      sourceName: source['name'] as String,
      license: source['license'] as String,
    );
  }

  /// `MM-DD`.
  final String date;
  final List<OnThisDayItem> items;
  final String sourceName;
  final String license;

  /// The first item linked to a title, else the first item.
  OnThisDayItem get featured {
    for (final i in items) {
      if (i.linkedTitleId != null) return i;
    }
    return items.first;
  }

  String get caption => 'From $sourceName · $license';
}
