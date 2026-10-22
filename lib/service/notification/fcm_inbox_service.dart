import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/service/notification/notification_inbox_store.dart';
import 'package:mprs_android/service/notification/user_notification_service.dart';

/// FCM-delivered notifications are persisted in SQLite. External/VIP/VVIP users
/// do not rely on `/api/user/get/allNotifications` (404 on server).
class FcmInboxService {
  FcmInboxService._();

  /// Admin/Internal still sync from server inbox APIs.
  static bool get usesRemoteInboxApi =>
      AuthDataHelper.isAdminUser() || AuthDataHelper.isInternalUser();

  /// Register token + topics, then load inbox (remote only for privileged roles).
  static Future<List<NotificationItem>> syncInbox({
    bool tryRemote = true,
  }) async {
    await FcmTokenService.syncToBackend();

    if (usesRemoteInboxApi && tryRemote) {
      debugPrint('🔔 Inbox sync: remote API (privileged user)');
      return UserNotificationService.loadWithRemoteSync();
    }

    debugPrint('🔔 Inbox sync: FCM/local cache only');
    return UserNotificationService.loadPersistedInbox();
  }

  /// Reload [NotificationInboxStore] from SQLite.
  static Future<List<NotificationItem>> refreshStore() async {
    return NotificationInboxStore.instance.reloadFromDatabase();
  }
}
