// Settings placeholder: only the theme and text size controls (S4 hooks).
// The full screen (voice, clear my data, about, credits) is S9.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final ctrl = ref.read(themeSettingsProvider.notifier);
    final c = context.mx;
    final reading = Theme.of(context).extension<MxReading>()!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MxPushedTopBar(title: 'Settings'),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        SettingsRow(
                          label: 'Licences',
                          showArrow: true,
                          isLast: !kDebugMode,
                          onTap: () => showLicensePage(context: context),
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
