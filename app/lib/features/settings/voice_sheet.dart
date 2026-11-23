// Voice picker: "Device default" plus the device's English voices. Tapping a
// voice saves it (`voice_name`) and speaks a short sample.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/tables/user_tables.dart' show SettingKeys;
import '../../data/providers.dart';
import '../reader/read_aloud.dart';
import 'voices.dart';

const voiceSample =
    'Octavian won the civil war and was given the name Augustus.';

/// What the Voice row shows for the stored `voice_name`.
String voiceRowValue(String stored, List<TtsVoice> voices) {
  if (stored.isEmpty) return 'Device default';
  for (final v in voices) {
    if (v.name == stored) return v.label;
  }
  return 'Device default';
}

Future<void> showVoiceSheet(BuildContext context) => showMxBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (_) => const _VoiceList(),
);

class _VoiceList extends ConsumerWidget {
  const _VoiceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final voices = ref.watch(ttsVoicesProvider);
    final settings = ref.watch(settingsMapProvider).value ?? const {};
    final stored = settings[SettingKeys.voiceName] ?? '';
    final speed = double.tryParse(settings[SettingKeys.voiceSpeed] ?? '') ?? 1;

    Future<void> pick(String name) async {
      await ref
          .read(databaseProvider)
          .settingsDao
          .write(SettingKeys.voiceName, name);
      final tts = ref.read(ttsEngineProvider);
      await tts.stop();
      // Not awaited: the sample plays while the sheet stays open.
      tts.speak(voiceSample, speed: speed, voiceName: name).ignore();
    }

    Widget option(String label, String name, {required bool last}) {
      final selected = stored == name;
      return Semantics(
        selected: selected,
        child: SettingsRow(
          label: label,
          isLast: last,
          value: selected ? 'Selected' : null,
          onTap: () => pick(name),
        ),
      );
    }

    final list = voices.value ?? const <TtsVoice>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Voice', style: MxText.emptyTitle.copyWith(color: c.text)),
        const SizedBox(height: 4),
        Text(
          'Tap a voice to hear it. Lessons are read in this voice.',
          style: MxText.body.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 12),
        option('Device default', '', last: list.isEmpty && !voices.isLoading),
        if (voices.isLoading)
          const Padding(padding: EdgeInsets.all(24), child: LoadingState()),
        for (var i = 0; i < list.length; i++)
          option(list[i].label, list[i].name, last: i == list.length - 1),
      ],
    );
  }
}
