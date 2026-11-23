// Device text-to-speech voices for the Voice setting (CONTRACTS 5.1
// `voice_name`, empty = device default). The list sits behind a provider so
// tests override it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:meta/meta.dart';

@immutable
class TtsVoice {
  const TtsVoice({required this.name, required this.locale, this.label = ''});

  /// The engine's id, stored as `voice_name`.
  final String name;
  final String locale;

  /// "English (US) 2": what the person sees.
  final String label;
}

const _localeNames = {
  'en-US': 'English (US)',
  'en-GB': 'English (UK)',
  'en-IN': 'English (India)',
  'en-AU': 'English (Australia)',
  'en-CA': 'English (Canada)',
  'en-ZA': 'English (South Africa)',
  'en-IE': 'English (Ireland)',
  'en-NZ': 'English (New Zealand)',
  'en-NG': 'English (Nigeria)',
  'en-PH': 'English (Philippines)',
  'en-SG': 'English (Singapore)',
};

/// Most voices shown per locale.
const maxVoicesPerLocale = 3;

bool _needsNetwork(Map<Object?, Object?> v, String name) {
  final flag = '${v['network_required'] ?? v['networkRequired'] ?? ''}';
  return flag == '1' ||
      flag.toLowerCase() == 'true' ||
      name.contains('network');
}

/// English voices only (the lessons are English), grouped by locale and
/// numbered within it, offline voices only, at most 3 per locale, because engine ids like `en-us-x-sfg-local` mean
/// nothing to a reader.
List<TtsVoice> parseVoices(Object? raw) {
  if (raw is! List) return const [];
  final found = <String, String>{}; // name -> locale
  for (final v in raw) {
    if (v is! Map) continue;
    final name = '${v['name'] ?? ''}';
    final locale = '${v['locale'] ?? ''}'.replaceAll('_', '-');
    if (name.isEmpty || !locale.toLowerCase().startsWith('en')) continue;
    if (_needsNetwork(v, name)) continue; // offline-first app
    found[name] = locale;
  }
  final names = found.keys.toList()
    ..sort((a, b) {
      final byLocale = found[a]!.compareTo(found[b]!);
      return byLocale != 0 ? byLocale : a.compareTo(b);
    });
  final counts = <String, int>{};
  return [
    for (final n in names)
      if ((counts[found[n]] ?? 0) < maxVoicesPerLocale)
        TtsVoice(
          name: n,
          locale: found[n]!,
          label:
              '${_localeNames[found[n]] ?? found[n]} '
              '${counts.update(found[n]!, (c) => c + 1, ifAbsent: () => 1)}',
        ),
  ];
}

final ttsVoicesProvider = FutureProvider.autoDispose<List<TtsVoice>>((
  ref,
) async {
  try {
    return parseVoices(await FlutterTts().getVoices);
  } catch (_) {
    return const []; // no engine: only "Device default" is offered
  }
});
