// Credits (CONTRACTS 2.8): fonts from a bundled asset (works offline), the
// rest from /v1/credits cached in `cached_docs['credits']`. Kept apart from
// ContentSource so fakes of that interface stay valid.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/credits.dart';
import '../providers.dart';

abstract interface class CreditsSource {
  /// GET /v1/credits body.
  Future<String> creditsJson();
}

/// Bundled sample until S12 wires the API.
class DevCreditsSource implements CreditsSource {
  DevCreditsSource(this.bundle);
  final AssetBundle bundle;

  @override
  Future<String> creditsJson() => bundle.loadString('assets/dev/credits.json');
}

class CreditsData {
  const CreditsData({required this.fonts, this.content});

  final List<FontCredit> fonts;

  /// Null when never fetched and offline: "Connect to load content credits."
  final ContentCredits? content;
}

class CreditsRepository {
  CreditsRepository(this.db, this.source, this.bundle);

  final AppDatabase db;
  final CreditsSource source;
  final AssetBundle bundle;

  Future<List<FontCredit>> fonts() async {
    final body = await bundle.loadString('assets/credits/fonts.json');
    return [
      for (final f
          in (jsonDecode(body) as Map<String, dynamic>)['fonts'] as List)
        FontCredit.fromJson(f as Map<String, dynamic>),
    ];
  }

  /// Fresh from the source (and cached), else the cached copy, else null.
  Future<ContentCredits?> content() async {
    try {
      final body = await source.creditsJson();
      final parsed = ContentCredits.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      await db.contentCacheDao.putDoc('credits', body);
      return parsed;
    } catch (_) {
      final cached = await db.contentCacheDao.doc('credits');
      if (cached == null) return null;
      try {
        return ContentCredits.fromJson(
          jsonDecode(cached.payload) as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<CreditsData> load() async =>
      CreditsData(fonts: await fonts(), content: await content());
}

final creditsSourceProvider = Provider<CreditsSource>(
  (_) => DevCreditsSource(rootBundle),
);

final creditsBundleProvider = Provider<AssetBundle>((_) => rootBundle);

final creditsRepositoryProvider = Provider<CreditsRepository>(
  (ref) => CreditsRepository(
    ref.watch(databaseProvider),
    ref.watch(creditsSourceProvider),
    ref.watch(creditsBundleProvider),
  ),
);

final creditsProvider = FutureProvider.autoDispose<CreditsData>(
  (ref) => ref.watch(creditsRepositoryProvider).load(),
);
