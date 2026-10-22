import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/model/notification_item.dart';
import 'package:mprs_android/service/notification/notification_inbox_refresh.dart';
import 'package:mprs_android/service/notification/user_notification_service.dart';

/// Holds notification tab state: previous cards stay, new ones merge in with their time.
class NotificationInboxStore extends ChangeNotifier {
  NotificationInboxStore._();

  static final NotificationInboxStore instance = NotificationInboxStore._();

  List<NotificationItem> _items = [];
  bool _hydrated = false;

  List<NotificationItem> get items => List.unmodifiable(_items);

  /// Load from SQLite (login / open tab). Does not re-sync shipments.
  Future<List<NotificationItem>> ensureLoaded({bool forceDb = false}) async {
    if (_hydrated && !forceDb) {
      return _items;
    }
    return reloadFromDatabase();
  }

  /// Call on logout so the next user does not see the previous inbox in memory.
  void clearSession() {
    _items = [];
    _hydrated = false;
    notifyListeners();
  }

  /// Read DB and merge — keeps in-memory times for cards already on screen.
  Future<List<NotificationItem>> reloadFromDatabase() async {
    final fromDb = await UserNotificationService.loadPersistedInbox();
    _items = _mergePreservingArrivalTimes(_items, fromDb);
    _hydrated = true;
    notifyListeners();
    return _items;
  }

  /// Call after a new row is saved — prepends one card, keeps all previous.
  void addNew(NotificationItem item) {
    if (item.id.isEmpty || !item.hasDisplayContent) return;

    final userType = AuthDataHelper.getUserType().trim();
    if (!item.isVisibleToUserType(userType)) return;

    if (_items.any(
      (e) =>
          e.id == item.id ||
          (item.notificationId.isNotEmpty &&
              e.notificationId == item.notificationId),
    )) {
      return;
    }

    _items = [item, ..._items]
      ..sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
    _hydrated = true;
    notifyListeners();
    NotificationInboxRefresh.bump();
    debugPrint('🔔 Inbox +1: ${item.displayTitle}');
  }

  /// In-memory list wins for same id (preserves arrival time on screen).
  static List<NotificationItem> _mergePreservingArrivalTimes(
    List<NotificationItem> current,
    List<NotificationItem> fromDb,
  ) {
    final byId = <String, NotificationItem>{};

    for (final item in fromDb) {
      if (item.id.isEmpty) continue;
      byId[item.id] = item;
    }

    for (final item in current) {
      if (item.id.isEmpty) continue;
      byId[item.id] = item;
    }

    return byId.values.toList()
      ..sort((a, b) => b.statusUpdatedAt.compareTo(a.statusUpdatedAt));
  }
}
