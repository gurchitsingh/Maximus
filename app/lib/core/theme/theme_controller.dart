// Theme and text size state. In memory for now: S9 persists these in the
// drift settings table (DECISIONS D22, no shared_preferences).
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

class ThemeSettingsController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() => const ThemeSettings();

  void setVariant(MxThemeVariant v) => state = state.copyWith(variant: v);
  void setTextSize(MxTextSize s) => state = state.copyWith(textSize: s);
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsController, ThemeSettings>(
      ThemeSettingsController.new,
    );
