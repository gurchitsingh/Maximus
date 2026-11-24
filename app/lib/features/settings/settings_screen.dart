// Settings (DESIGN_SPEC 9 4.1): theme, text size, voice speed, then the
// list: Voice, Clear my data, About, Credits.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/tables/user_tables.dart' show SettingKeys;
import '../../data/providers.dart';
import 'about_sheet.dart';
import 'clear_data.dart';
import 'voice_sheet.dart';
import 'voices.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final ctrl = ref.read(themeSettingsProvider.notifier);
    final c = context.mx;
    final stored = ref.watch(settingsMapProvider).value ?? const {};
    final reading = Theme.of(context).extension<MxReading>()!;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const MxTabTopBar(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Group(
                    label: 'Theme',
                    child: SegmentedChoice<MxThemeVariant>(
                      options: MxThemeVariant.values,
                      value: settings.variant,
                      labelOf: (v) => v.label,
                      onChanged: ctrl.setVariant,
                    ),
                  ),
                  _Group(
                    label: 'Text size',
                    child: SegmentedChoice<MxTextSize>(
                      options: MxTextSize.values,
                      value: settings.textSize,
                      labelOf: (s) => s.label,
                      onChanged: ctrl.setTextSize,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      'Sample: Octavian won the civil war and was given the name Augustus.',
                      style: reading.paragraph.copyWith(color: c.text),
                    ),
                  ),
                  _Group(
                    label: 'Voice speed',
                    child: SegmentedChoice<String>(
                      options: const ['0.8', '1.0', '1.2'],
                      value: stored[SettingKeys.voiceSpeed] ?? '1.0',
                      labelOf: (v) => v == '1.0' ? '1x' : '${v}x',
                      onChanged: (v) => ref
                          .read(databaseProvider)
                          .settingsDao
                          .write('voice_speed', v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        SettingsRow(
                          label: 'Voice',
                          value: voiceRowValue(
                            stored[SettingKeys.voiceName] ?? '',
                            ref.watch(ttsVoicesProvider).value ?? const [],
                          ),
                          showArrow: true,
                          onTap: () => showVoiceSheet(context),
                        ),
                        SettingsRow(
                          label: 'Clear my data',
                          value: 'Topics, scores, settings',
                          destructive: true,
                          onTap: () => clearMyDataFlow(context, ref),
                        ),
                        SettingsRow(
                          label: 'About',
                          value: 'Version 1.0',
                          onTap: () => showAboutSheet(context),
                        ),
                        SettingsRow(
                          label: 'Credits',
                          showArrow: true,
                          isLast: !kDebugMode,
                          onTap: () => context.push(AppRoute.credits.path),
                        ),
                        if (kDebugMode)
                          SettingsRow(
                            label: 'Widget gallery',
                            value: 'Debug only',
                            isLast: true,
                            onTap: () => context.push(AppRoute.gallery.path),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), const SizedBox(height: 10), child],
      ),
    );
  }
}
