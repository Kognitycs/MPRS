import 'package:flutter/foundation.dart';

/// Bumps when a push notification is saved — NotificationScreen listens and reloads.
class NotificationInboxRefresh {
  NotificationInboxRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier(0);

  static void bump() => tick.value++;
}
