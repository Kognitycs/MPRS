import 'dart:convert';
// import 'dart:ffi';  <-- YE LINE DELETE KAR DI HAI

import 'package:get_storage/get_storage.dart';
import 'package:mprs_android/model/common/user_data.dart';

class DbHelper {
  static late GetStorage getStorage;
  static const String _userModel = "userModel";
  static const String _userRole = "userRole";
  static const String _userId = "userId";
  static const String _userToken = "userToken";
  static const String _isLoggedIn = "isLoggedIn";
  static const JsonDecoder _decoder = JsonDecoder();
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');
  static final DbHelper _singleton = DbHelper._internal();
  static const String _notificationOnOff = 'notificationOnOff';

  DbHelper._internal() {
    // Note: init() async hai, toh getStorage assign hone mein time lag sakta hai.
    // Isliye initialize main.dart mein karna best hai.
    getStorage = GetStorage();
  }

  static Future<void> init() async {
    await GetStorage.init();
    getStorage = GetStorage();
  }

  factory DbHelper() {
    return _singleton;
  }

  _savePref(String key, Object? value) async {
    var prefs = getStorage;
    if (prefs.hasData(key)) {
      prefs.remove(key);
    }
    if (value is bool) {
      return prefs.write(key, value);
    } else if (value is int) {
      return prefs.write(key, value);
    } else if (value is String) {
      return prefs.write(key, value);
    } else if (value is double) { // Fixed: Changed 'Double' or 'Float' to 'double'
      return prefs.write(key, value);
    }
  }

  T _getPref<T>(String key) {
    return getStorage.read(key) as T;
  }

  void clearAll() {
    getStorage.erase();
  }

  String? getUserId() {
    return _getPref(_userId);
  }

  String? getUserRole() {
    return _getPref(_userRole);
  }

  void saveUserRole(String? userRole) {
    _savePref(_userRole, userRole);
  }

  String? getTourId() {
    return _getPref("tourId");
  }

  void saveTourId(String? tourId) {
    _savePref("tourId", tourId);
  }

  void saveUserId(String? userId) {
    _savePref(_userId, userId);
  }

  String? getUserToken() {
    return _getPref(_userToken);
  }

  void saveUserToken(String? token) {
    _savePref(_userToken, token);
  }

  UserData? getUserModel() {
    try {
      String? user = _getPref(_userModel);
      if (user != null) {
        Map<String, dynamic> userMap = _decoder.convert(user);
        return UserData.fromJson(userMap);
      }
    } catch (e) {
      print("Error reading user model: $e");
    }
    return null;
  }

  void saveUserModel(UserData? userModel) {
    if (userModel != null) {
      String value = _encoder.convert(userModel);
      _savePref(_userModel, value);
    } else {
      _savePref(_userModel, null);
    }
  }

  bool getIsLoggedIn() {
    try {
      return _getPref(_isLoggedIn) ?? false;
    } catch (e) {
      return false;
    }
  }

  void saveIsLoggedIn(bool value) {
    _savePref(_isLoggedIn, value);
  }

  bool getIsNotificationOn() {
    try {
      return _getPref(_notificationOnOff) ?? true;
    } catch (e) {
      return true;
    }
  }

  void saveIsNotificationOn(bool value) {
    _savePref(_notificationOnOff, value);
  }
}