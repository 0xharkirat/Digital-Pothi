import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(ThemeCubit, () {
    test('defaults to dark; setLight flips and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      final cubit = ThemeCubit(prefs);
      expect(cubit.state, ThemeMode.dark);

      cubit.setLight(light: true);
      expect(cubit.state, ThemeMode.light);
      expect(cubit.isLight, isTrue);

      // Persisted: a fresh cubit over the same store restores light.
      expect(ThemeCubit(prefs).state, ThemeMode.light);
      await cubit.close();
    });
  });
}
