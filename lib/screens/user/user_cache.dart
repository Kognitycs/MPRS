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

  /// When list rows omit `accountId`, use tag stored after add-user / edit tag.
  static final Map<String, String> _accountIdByUserKey = {};

  static void rememberAccountTag({
    String? userId,
    String? mongoId,
    required String accountId,
  }) {
    final tag = accountId.trim();
    if (tag.isEmpty) return;
    for (final key in [userId, mongoId]) {
      final k = key?.trim();
      if (k != null && k.isNotEmpty) {
        _accountIdByUserKey[k] = tag;
      }
    }
    _patchListsWithAccountId(userId, mongoId, tag);
  }

  static String? localAccountId({String? userId, String? mongoId}) {
    for (final key in [userId, mongoId]) {
      final k = key?.trim();
      if (k == null || k.isEmpty) continue;
      final found = _accountIdByUserKey[k];
      if (found != null && found.isNotEmpty) return found;
    }
    return null;
  }

  static void _patchListsWithAccountId(
    String? userId,
    String? mongoId,
    String accountId,
  ) {
    for (final notifier in _userTypeNotifiers.values) {
      final updated = notifier.value.map((u) {
        final matches =
            (userId != null &&
                userId.isNotEmpty &&
                (u.userId?.trim() == userId || u.id?.trim() == userId)) ||
            (mongoId != null &&
                mongoId.isNotEmpty &&
                (u.userId?.trim() == mongoId || u.id?.trim() == mongoId));
        if (!matches) return u;
        return u.copyWith(accountId: accountId);
      }).toList();
      notifier.value = updated;
    }
  }
}
