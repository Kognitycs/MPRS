import 'package:flutter/foundation.dart';
import 'package:mprs_android/model/common/user_data.dart';

class UserCache {
  // Per userType cache: e.g., 'All', 'Admin', 'Internal', etc.
  static final Map<String, ValueNotifier<List<UserData>>> _userTypeNotifiers = {};
  static final Map<String, int> userTypePage = {};
  static final Map<String, int> userTypeTotalPages = {};
  static final Map<String, bool> userTypeIsLoading = {};

  static ValueNotifier<List<UserData>> _getNotifier(String userType) {
    return _userTypeNotifiers.putIfAbsent(userType, () => ValueNotifier<List<UserData>>([]));
  }
  
  static List<UserData> getUsers(String userType) => _getNotifier(userType).value;
  static ValueNotifier<List<UserData>> getNotifier(String userType) => _getNotifier(userType);
  static int getPage(String userType) => userTypePage[userType] ?? 1;
  static int getTotalPages(String userType) => userTypeTotalPages[userType] ?? 1;
  static bool getIsLoading(String userType) => userTypeIsLoading[userType] ?? false;

  static void setUsers(String userType, List<UserData> users) {
    _getNotifier(userType).value = users;
  }
  static void clearUsers(String userType) {
    _getNotifier(userType).value = [];
  }
  static void setPage(String userType, int page) {
    userTypePage[userType] = page;
  }
  static void setTotalPages(String userType, int totalPages) {
    userTypeTotalPages[userType] = totalPages;
  }
  static void setIsLoading(String userType, bool isLoading) {
    userTypeIsLoading[userType] = isLoading;
  }
}
