// Theme and text size state, persisted in the drift `settings` table
// (CONTRACTS 5.1, DECISIONS D22: no shared_preferences). main() reads the
// stored values before the first frame (no theme flash) and overrides
// [initialThemeSettingsProvider] and [settingsWriterProvider]; without those
// overrides (tests, gallery) the state lives in memory only.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'typography.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({
    this.variant = MxThemeVariant.dark,
    this.textSize = MxTextSize.medium,
  });

  /// From the stored `theme` and `text_size` values; unknown values fall
  /// back to the defaults (dark, medium).
  factory ThemeSettings.fromStored(Map<String, String> s) => ThemeSettings(
    variant: MxThemeVariant.values.firstWhere(
      (v) => v.name == s[themeKey],
      orElse: () => MxThemeVariant.dark,
    ),
    textSize: MxTextSize.values.firstWhere(
      (v) => v.name == s[textSizeKey],
      orElse: () => MxTextSize.medium,
    ),
  );

  static const themeKey = 'theme';
  static const textSizeKey = 'text_size';

  final MxThemeVariant variant;
  final MxTextSize textSize;

  ThemeSettings copyWith({MxThemeVariant? variant, MxTextSize? textSize}) =>
      ThemeSettings(
        variant: variant ?? this.variant,
        textSize: textSize ?? this.textSize,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.variant == variant &&
      other.textSize == textSize;

  @override
  int get hashCode => Object.hash(variant, textSize);
}

/// Writes one setting. Implemented by the drift SettingsDao.
abstract interface class SettingsWriter {
  Future<void> write(String key, String value);
}

final initialThemeSettingsProvider = Provider<ThemeSettings>(
  (_) => const ThemeSettings(),
);

final settingsWriterProvider = Provider<SettingsWriter?>((_) => null);

class ThemeSettingsController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() => ref.read(initialThemeSettingsProvider);

  void setVariant(MxThemeVariant v) {
    state = state.copyWith(variant: v);
    ref.read(settingsWriterProvider)?.write(ThemeSettings.themeKey, v.name);
  }

  void setTextSize(MxTextSize s) {
    state = state.copyWith(textSize: s);
    ref.read(settingsWriterProvider)?.write(ThemeSettings.textSizeKey, s.name);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsController, ThemeSettings>(
      ThemeSettingsController.new,
    );
