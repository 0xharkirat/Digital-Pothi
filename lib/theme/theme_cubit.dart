import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/preferences.dart';

/// The operator app theme (STTM's Colors: Light / Dark), persisted. A Cubit
/// like the rest of the app - it sits above the MaterialApp so a BlocBuilder
/// there flips the theme live. The projected display stays dark regardless
/// (the sangat's surface is fixed by the GurbaniTheme tokens).
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._prefs)
    : super((_prefs.getBool(_key) ?? false) ? ThemeMode.light : ThemeMode.dark);

  static const _key = 'lightTheme';
  final Preferences _prefs;

  bool get isLight => state == ThemeMode.light;

  void setLight({required bool light}) {
    _prefs.setBool(_key, value: light);
    emit(light ? ThemeMode.light : ThemeMode.dark);
  }
}
