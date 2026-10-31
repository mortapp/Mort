import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MortExperiencePreferences {
  const MortExperiencePreferences({
    this.reducedMotion = false,
    this.reducedTransparency = false,
    this.highContrast = false,
    this.hapticsEnabled = true,
    this.themeMode = ThemeMode.light,
  });

  final bool reducedMotion;
  final bool reducedTransparency;
  final bool highContrast;
  final bool hapticsEnabled;
  final ThemeMode themeMode;

  MortExperiencePreferences copyWith({
    bool? reducedMotion,
    bool? reducedTransparency,
    bool? highContrast,
    bool? hapticsEnabled,
    ThemeMode? themeMode,
  }) => MortExperiencePreferences(
    reducedMotion: reducedMotion ?? this.reducedMotion,
    reducedTransparency: reducedTransparency ?? this.reducedTransparency,
    highContrast: highContrast ?? this.highContrast,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    themeMode: themeMode ?? this.themeMode,
  );
}

class MortExperiencePreferencesController
    extends AsyncNotifier<MortExperiencePreferences> {
  static const _reducedMotionKey = 'mort.preference.reduced_motion';
  static const _reducedTransparencyKey = 'mort.preference.reduced_transparency';
  static const _highContrastKey = 'mort.preference.high_contrast';
  static const _hapticsEnabledKey = 'mort.preference.haptics_enabled';
  static const _themeModeKey = 'mort.preference.theme_mode';

  @override
  Future<MortExperiencePreferences> build() async {
    final preferences = await SharedPreferences.getInstance();
    return MortExperiencePreferences(
      reducedMotion: preferences.getBool(_reducedMotionKey) ?? false,
      reducedTransparency:
          preferences.getBool(_reducedTransparencyKey) ?? false,
      highContrast: preferences.getBool(_highContrastKey) ?? false,
      hapticsEnabled: preferences.getBool(_hapticsEnabledKey) ?? true,
      themeMode: switch (preferences.getString(_themeModeKey)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
    );
  }

  Future<void> setReducedMotion(bool value) => _save(
    key: _reducedMotionKey,
    value: value,
    update: (current) => current.copyWith(reducedMotion: value),
  );

  Future<void> setReducedTransparency(bool value) => _save(
    key: _reducedTransparencyKey,
    value: value,
    update: (current) => current.copyWith(reducedTransparency: value),
  );

  Future<void> setHighContrast(bool value) => _save(
    key: _highContrastKey,
    value: value,
    update: (current) => current.copyWith(highContrast: value),
  );

  Future<void> setHapticsEnabled(bool value) => _save(
    key: _hapticsEnabledKey,
    value: value,
    update: (current) => current.copyWith(hapticsEnabled: value),
  );

  Future<void> setThemeMode(ThemeMode value) => _saveString(
    key: _themeModeKey,
    value: switch (value) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    },
    update: (current) => current.copyWith(themeMode: value),
  );

  Future<void> applyOnboardingPreferences({
    required bool reducedMotion,
    required bool highContrast,
  }) async {
    await setReducedMotion(reducedMotion);
    await setHighContrast(highContrast);
  }

  Future<void> _save({
    required String key,
    required bool value,
    required MortExperiencePreferences Function(
      MortExperiencePreferences current,
    )
    update,
  }) async {
    final current = state.value ?? const MortExperiencePreferences();
    final next = update(current);
    state = AsyncData(next);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setBool(key, value);
      if (!saved) throw StateError('Preference was not saved.');
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> _saveString({
    required String key,
    required String value,
    required MortExperiencePreferences Function(
      MortExperiencePreferences current,
    )
    update,
  }) async {
    final current = state.value ?? const MortExperiencePreferences();
    final next = update(current);
    state = AsyncData(next);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(key, value);
      if (!saved) throw StateError('Preference was not saved.');
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final mortExperiencePreferencesProvider =
    AsyncNotifierProvider<
      MortExperiencePreferencesController,
      MortExperiencePreferences
    >(MortExperiencePreferencesController.new);

class MortExperiencePreferencesScope extends InheritedWidget {
  const MortExperiencePreferencesScope({
    super.key,
    required this.preferences,
    required super.child,
  });

  final MortExperiencePreferences preferences;

  static MortExperiencePreferences of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MortExperiencePreferencesScope>()
          ?.preferences ??
      const MortExperiencePreferences();

  @override
  bool updateShouldNotify(MortExperiencePreferencesScope oldWidget) =>
      preferences != oldWidget.preferences;
}

class MortHaptics {
  const MortHaptics._();

  static Future<void> selectionClick(BuildContext context) async {
    if (MortExperiencePreferencesScope.of(context).hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  static Future<void> success(BuildContext context) async {
    if (MortExperiencePreferencesScope.of(context).hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> warning(BuildContext context) async {
    if (MortExperiencePreferencesScope.of(context).hapticsEnabled) {
      await HapticFeedback.vibrate();
    }
  }
}
