import 'package:shared_preferences/shared_preferences.dart';

/// A thin wrapper over [SharedPreferences] - the local, on-device store for
/// operator settings (bani length, display options, ...) and session history, so
/// they survive a restart. Kept primitive-typed on purpose: the cubit maps enums
/// and JSON, so this stays free of any presenter types.
class Preferences {
  Preferences(this._sp);

  final SharedPreferences _sp;

  /// Load the on-device store. Call once at startup.
  static Future<Preferences> load() async =>
      Preferences(await SharedPreferences.getInstance());

  int? getInt(String key) => _sp.getInt(key);
  bool? getBool(String key) => _sp.getBool(key);
  double? getDouble(String key) => _sp.getDouble(key);
  String? getString(String key) => _sp.getString(key);

  void setInt(String key, int value) => _sp.setInt(key, value);
  void setBool(String key, {required bool value}) => _sp.setBool(key, value);
  void setDouble(String key, double value) => _sp.setDouble(key, value);
  void setString(String key, String value) => _sp.setString(key, value);
}
