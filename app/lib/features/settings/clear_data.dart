// "Clear my data" (CONTRACTS 5.1, D18, DESIGN_SPEC 11.14): confirm, empty the
// personal tables in one transaction, reset live state, go to the splash.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../reader/read_aloud.dart';

Future<bool> confirmClearData(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: MxFixed.sheetBackdrop,
    builder: (ctx) {
      final c = ctx.mx;
      return Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MxRadius.sheet),
          side: BorderSide(color: c.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Clear my data?',
                style: MxText.emptyTitle.copyWith(color: c.text),
              ),
              const SizedBox(height: 10),
              Text(
                'This removes your topics, study list, ratings, progress, '
                'quiz scores and settings from this phone. It cannot be '
                'undone. Lessons you have opened stay saved so the app still '
                'works offline.',
                style: MxText.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                label: 'Keep my data',
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: MxPressable(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  fill: c.error,
                  child: Center(
                    child: Text(
                      'Clear my data',
                      style: MxText.buttonL.copyWith(color: c.onAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok ?? false;
}

/// Confirms, clears, and routes to the splash. Returns whether it cleared.
Future<bool> clearMyDataFlow(BuildContext context, WidgetRef ref) async {
  if (!await confirmClearData(context)) return false;
  await ref.read(readAloudProvider.notifier).stop();
  await ref.read(databaseProvider).clearMyData();
  ref.read(themeSettingsProvider.notifier).reset();
  if (context.mounted) context.go(AppRoute.splash.path);
  return true;
}
