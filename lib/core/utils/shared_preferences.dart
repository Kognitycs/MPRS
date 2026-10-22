import 'package:shared_preferences/shared_preferences.dart';

class PreferenceUtils {
  static late SharedPreferences _prefsInstance;

  // Initialize in main
  static Future<void> init() async {
    _prefsInstance = await SharedPreferences.getInstance();
  }

  static String getString(String key, [String defValue = ""]) {
    if (_prefsInstance == null) return defValue;
    return _prefsInstance!.getString(key) ?? defValue;
  }

  static Future<bool> setString(String key, String value) async {
    return await _prefsInstance.setString(key, value);
  }

  static int getInt(String key, [int defValue = 0]) {
    return _prefsInstance.getInt(key) ?? defValue;
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefsInstance.setInt(key, value);
  }

  static bool getBool(String key, [bool defValue = false]) {
    return _prefsInstance.getBool(key) ?? defValue;
  }

  static Future<bool> setBool(String key, bool value) async {
    return await _prefsInstance.setBool(key, value);
  }

  static double getDouble(String key, [double defValue = 0.0]) {
    return _prefsInstance.getDouble(key) ?? defValue;
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefsInstance.setDouble(key, value);
  }

  static List<String> getStringList(String key,
      [List<String> defValue = const []]) {
    return _prefsInstance.getStringList(key) ?? defValue;
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefsInstance.setStringList(key, value);
  }

  static Future<bool> remove(String key) async {
    return await _prefsInstance.remove(key);
  }

  static Future<bool> clear() async {
    return await _prefsInstance.clear();
  }
}
