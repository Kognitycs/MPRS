import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/service/notification/fcm_inbox_service.dart';
import 'package:mprs_android/service/notification/notification_inbox_store.dart';
import 'package:mprs_android/service/notification/notification_service.dart';
import 'package:mprs_android/service/notification/user_notification_service.dart';

/// Keeps the inbox in sync — FCM + SQLite for users; optional API for admin.
class NotificationPollService {
  NotificationPollService._();

  /// Seen state is stored per logged-in user so accounts do not share read state.
  static String _seenPrefsKey() {
    final id = AuthDataHelper.getId().trim();
    if (id.isNotEmpty) return 'notification_seen_ids_v1_$id';
    final mobile = AuthDataHelper.getMobile().trim();
    if (mobile.isNotEmpty) return 'notification_seen_ids_v1_m_$mobile';
    return 'notification_seen_ids_v1';
  }

  static Set<String> loadSeenIds() =>
      PreferenceUtils.getStringList(_seenPrefsKey()).toSet();

  static String itemKey(NotificationItem item) {
    if (item.notificationId.trim().isNotEmpty) {
      return item.notificationId.trim();
    }
    if (item.id.trim().isNotEmpty) return item.id.trim();
    return '${item.messageHeader}_${item.createdAt.millisecondsSinceEpoch}';
  }

  /// Unread count for the home bell — matches [NotificationScreen] visibility.
  static int unreadCount(Iterable<NotificationItem> items) {
    final seen = loadSeenIds();
    final role = AuthDataHelper.getUserType().trim().toLowerCase();
    return items
      .where((n) {
        if (!n.hasDisplayContent) return false;
        if (role.isNotEmpty && !n.isVisibleToUserType(role)) return false;
        final key = itemKey(n);
        return key.isNotEmpty && !seen.contains(key);
      })
      .length;
  }

  /// Call when the user opens the notification inbox — clears the home badge.
  static Future<void> markVisibleInboxAsSeen() async {
    final role = AuthDataHelper.getUserType().trim().toLowerCase();
    final visible =
        NotificationInboxStore.instance.items.where((n) {
          if (!n.hasDisplayContent) return false;
          if (role.isNotEmpty && !n.isVisibleToUserType(role)) return false;
          return true;
        }).toList();
    if (visible.isEmpty) return;

    final before = loadSeenIds();
    final nextSeen = {
      ...before,
      ...visible.map(itemKey).where((k) => k.isNotEmpty),
    };
    await PreferenceUtils.setStringList(_seenPrefsKey(), nextSeen.toList());
    NotificationInboxStore.instance.notifyBadgeChanged();
  }

  /// Sync FCM token, reload local inbox, alert about new FCM-persisted items.
  static Future<void> syncAndAlert({bool showBannerForNew = true}) async {
    final role = AuthDataHelper.getUserType().trim().toLowerCase();
    if (role.isEmpty) return;

    List<NotificationItem> merged;
    try {
      merged = await FcmInboxService.syncInbox(
        tryRemote: FcmInboxService.usesRemoteInboxApi,
      );
    } catch (e) {
      debugPrint('🔔 Notification sync failed: $e');
      merged = await UserNotificationService.loadPersistedInbox();
    }

    await NotificationInboxStore.instance.reloadFromDatabase();

    final before = loadSeenIds();
    final visible =
        merged.where((n) => n.isVisibleToUserType(role)).toList();

    // Historic inbox rows stay "unread" until the user opens notifications.
    // Only surface banners for items not in the seen set.
    final newItems =
        visible.where((n) {
          final key = itemKey(n);
          return key.isNotEmpty && !before.contains(key);
        }).toList();

    if (newItems.isNotEmpty) {
      // Banner only — do not auto-mark as seen (badge stays until inbox is opened).

      if (showBannerForNew) {
        for (final item in newItems) {
          if (!item.isAdminPush && !item.isShipmentAlert) continue;
          await NotificationServices.showPushAlert(
            title: item.displayTitle,
            body: item.displayBody.isNotEmpty
                ? item.displayBody
                : item.messageBody,
            payload: jsonEncode({
              'notificationId': item.notificationId,
              'messageHeader': item.messageHeader,
              'messageBody': item.messageBody,
              'targetUsers': item.targetUsers,
              'approvalType': 'notification',
              'status': 'received',
            }),
          );
        }
      }
    }
    NotificationInboxStore.instance.notifyBadgeChanged();
  }

  static Future<void> clearSeenOnLogout() async {
    await PreferenceUtils.remove(_seenPrefsKey());
  }
}
