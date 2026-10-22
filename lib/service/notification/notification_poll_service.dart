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

  static const _prefSeenIds = 'notification_seen_ids_v1';

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

    final before = _loadSeenIds();
    final visible =
        merged.where((n) => n.isVisibleToUserType(role)).toList();

    if (before.isEmpty && visible.isNotEmpty) {
      await PreferenceUtils.setStringList(
        _prefSeenIds,
        visible.map(_itemKey).where((k) => k.isNotEmpty).toList(),
      );
      return;
    }

    final newItems =
        visible.where((n) {
          final key = _itemKey(n);
          return key.isNotEmpty && !before.contains(key);
        }).toList();

    if (newItems.isNotEmpty) {
      final nextSeen = {...before, ...newItems.map(_itemKey)};
      await PreferenceUtils.setStringList(_prefSeenIds, nextSeen.toList());

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
  }

  static Set<String> _loadSeenIds() =>
      PreferenceUtils.getStringList(_prefSeenIds).toSet();

  static String _itemKey(NotificationItem item) {
    if (item.notificationId.trim().isNotEmpty) {
      return item.notificationId.trim();
    }
    if (item.id.trim().isNotEmpty) return item.id.trim();
    return '${item.messageHeader}_${item.createdAt.millisecondsSinceEpoch}';
  }

  static Future<void> clearSeenOnLogout() async {
    await PreferenceUtils.remove(_prefSeenIds);
  }
}
