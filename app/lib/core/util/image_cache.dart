// Image cache for content art (CONTRACTS 3.6 "Images"): its own cache
// manager, stale period 365 days and 3000 objects, so prefetched lesson
// images stay available offline. A failed image falls back to the tinted
// gradient in the widgets.
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Lazily created on first use (tests that never show a network image never
/// touch path_provider).
final BaseCacheManager mxImageCache = CacheManager(
  Config(
    'mx_images',
    stalePeriod: const Duration(days: 365),
    maxNrOfCacheObjects: 3000,
  ),
);

/// The sample payloads point at placeholder files on example.org/com that do
/// not exist; never fetch those.
bool isPlaceholderImageUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'example.org' || host == 'example.com';
}

/// Downloads [urls] into [cache], at most [parallel] at once. Failures are
/// ignored: the image loads (or falls back) when it is shown.
Future<void> prefetchImages(
  Iterable<String> urls, {
  BaseCacheManager? cache,
  int parallel = 3,
}) async {
  final queue = [
    for (final u in urls.toSet())
      if (!isPlaceholderImageUrl(u)) u,
  ];
  final manager = cache ?? mxImageCache;
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final url = queue.removeLast();
      try {
        await manager.getSingleFile(url);
      } catch (_) {
        // Offline or a bad file: shown later or as the gradient.
      }
    }
  }

  await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
}
