// Read aloud with flutter_tts (DESIGN_SPEC 9.3.1, 7.22). The engine sits
// behind [TtsEngine] so widget tests use a fake.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class TtsEngine {
  /// Completes when the text has been spoken, or after [stop].
  Future<void> speak(String text, {required double speed, String? voiceName});
  Future<void> stop();
}

/// Android TTS takes at most about 4000 characters per call, so long
/// lessons are spoken in sentence-sized chunks one after the other.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  int _session = 0;

  @override
  Future<void> speak(
    String text, {
    required double speed,
    String? voiceName,
  }) async {
    final session = ++_session;
    await _tts.awaitSpeakCompletion(true);
    // flutter_tts on Android: 0.5 is the normal rate.
    await _tts.setSpeechRate((0.5 * speed).clamp(0.1, 1.0));
    if (voiceName != null && voiceName.isNotEmpty) {
      final voices = await _tts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map && v['name'] == voiceName) {
            await _tts.setVoice({
              'name': '${v['name']}',
              'locale': '${v['locale']}',
            });
          }
        }
      }
    }
    for (final chunk in ttsChunks(text)) {
      if (session != _session) return; // stopped or restarted
      await _tts.speak(chunk);
    }
  }

  @override
  Future<void> stop() async {
    _session++;
    await _tts.stop();
  }
}

/// Splits [text] at sentence ends into chunks of at most [max] characters.
List<String> ttsChunks(String text, {int max = 3500}) {
  final sentences = RegExp(r'[^.!?\n]+[.!?]*\s*').allMatches(text);
  final out = <String>[];
  final buf = StringBuffer();
  for (final m in sentences) {
    var s = m.group(0)!;
    while (s.length > max) {
      // A single sentence longer than max: hard split.
      if (buf.isNotEmpty) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      out.add(s.substring(0, max).trim());
      s = s.substring(max);
    }
    if (buf.length + s.length > max) {
      out.add(buf.toString().trim());
      buf.clear();
    }
    buf.write(s);
  }
  if (buf.toString().trim().isNotEmpty) out.add(buf.toString().trim());
  return out.where((c) => c.isNotEmpty).toList();
}

final ttsEngineProvider = Provider<TtsEngine>((ref) {
  final engine = FlutterTtsEngine();
  ref.onDispose(engine.stop);
  return engine;
});

/// The lesson id being read aloud, or null.
class ReadAloudController extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> toggle({
    required String lessonId,
    required String text,
    required double speed,
    String? voiceName,
  }) async {
    final engine = ref.read(ttsEngineProvider);
    if (state == lessonId) {
      state = null;
      await engine.stop();
      return;
    }
    if (state != null) await engine.stop();
    state = lessonId;
    try {
      await engine.speak(text, speed: speed, voiceName: voiceName);
    } finally {
      if (state == lessonId) state = null;
    }
  }

  Future<void> stop() async {
    if (state == null) return;
    state = null;
    await ref.read(ttsEngineProvider).stop();
  }
}

final readAloudProvider = NotifierProvider<ReadAloudController, String?>(
  ReadAloudController.new,
);
