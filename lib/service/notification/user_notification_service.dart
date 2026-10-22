import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/core/database/notification_db.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/service/notification/fcm_inbox_service.dart';

/// Loads the notification inbox from local storage (no login sync).
class UserNotificationService {
  /// Notifications tab / login: read saved cards only — never sync shipments here.
  static Future<List<NotificationItem>> loadPersistedInbox() async {
    final userType = AuthDataHelper.getUserType().trim();
    final accountId = _currentAccountId();

    final persisted = await NotificationDB.instance.getAll();
    final merged = _merge(persisted, userType, accountId);

    debugPrint(
      '🔔 Persisted inbox: ${merged.length} card(s) account=$accountId',
    );
    return merged;
  }

  static String _currentAccountId() {
    final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return AuthDataHelper.getAccountId().trim();
  }

  /// Pull-to-refresh: optional remote sync for Admin/Internal; local for others.
  static Future<List<NotificationItem>> loadWithRemoteSync() async {
    if (!FcmInboxService.usesRemoteInboxApi) {
      debugPrint('🔔 loadWithRemoteSync: skipped remote API — using FCM cache');
      return loadPersistedInbox();
    }

    final userType = AuthDataHelper.getUserType().trim();
    final accountId = DbHelper().getUserModel()?.accountId?.trim() ?? '';

    final server = await ApiProvider().fetchInboxNotifications();
    debugPrint('🔔 loadWithRemoteSync: server=${server.length} items, userType=$userType');
    if (server.isNotEmpty) {
      await NotificationDB.instance.upsertServerItems(server);
      debugPrint('🔔 Saved ${server.length} server items to SQLite');
    }

    final persisted = await NotificationDB.instance.getAll();
    final merged = _merge(persisted, userType, accountId);
    debugPrint('🔔 Merged inbox: ${merged.length} items to show');
    return merged;
  }

  /// Default loader for notification screen — local only (no login sync).
  static Future<List<NotificationItem>> loadForCurrentUser() =>
      loadPersistedInbox();

  static List<NotificationItem> _merge(
    List<NotificationItem> all,
    String userType,
    String accountId,
  ) {
    final byKey = <String, NotificationItem>{};

    void add(NotificationItem item) {
      if (!item.hasDisplayContent) return;

      if (item.isShipmentAlert &&
          accountId.isNotEmpty &&
          !item.belongsToAccount(accountId)) {
        return;
      }

      if (!item.isVisibleToUserType(userType)) return;

      if (!item.isShipmentAlert &&
          accountId.isNotEmpty &&
          item.ownerAccountId?.trim().isNotEmpty == true &&
          item.ownerAccountId!.trim() != accountId) {
        return;
      }

      final key =
          item.notificationId.isNotEmpty
              ? item.notificationId
              : (item.id.isNotEmpty ? item.id : null);
      if (key == null || key.isEmpty) {
        final fallback =
            '${item.messageHeader}_${item.statusUpdatedAt.millisecondsSinceEpoch}';
        final existing = byKey[fallback];
        if (existing == null ||
            item.statusUpdatedAt.isAfter(existing.statusUpdatedAt)) {
          byKey[fallback] = item;
        }
        return;
      }

      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = item;
        return;
      }

      if (existing.isShipmentAlert) return;

      if (item.updatedAt.isAfter(existing.updatedAt)) {
        byKey[key] = item;
      }
    }

    for (final item in all) {
      add(item);
    }

    final list = byKey.values.toList();
    list.sort((a, b) {
      final t = b.statusUpdatedAt.compareTo(a.statusUpdatedAt);
      if (t != 0) return t;
      return b.id.compareTo(a.id);
    });
    return list;
  }
}
