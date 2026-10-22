import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/edit_profile_controller.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/firebase/firebase_app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/database/notification_db.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/extension/target_extension.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/screens/home_screen/pending_approvals.dart';
import 'package:mprs_android/screens/banner/banner_screen.dart';
import 'package:mprs_android/screens/profile/edit_user_profile_screen.dart';
import 'package:mprs_android/main.dart' show navigatorKey;
import 'package:mprs_android/model/common/user_data.dart';

import '../../model/notification_item.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'notification_inbox_store.dart';

class NotificationServices {
  static String messageId = "";

  /// Registered by MainScreen so that tapping a regular push notification
  /// switches the app to the Notification tab without importing screen classes here.
  static VoidCallback? onOpenNotificationTab;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool get _hasFirebase => Firebase.apps.isNotEmpty;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  // ================= SETUP =================

  static const String _androidNotificationIcon = '@drawable/ic_notification';

  static AndroidNotificationDetails _buildAndroidNotificationDetails() {
    return AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: _androidNotificationIcon,
      largeIcon: DrawableResourceAndroidBitmap(_androidNotificationIcon),
    );
  }

  Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(_androidNotificationIcon);

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Local notification tapped');
        if (response.payload == null || response.payload!.isEmpty) {
          NotificationServices.onOpenNotificationTab?.call();
          return;
        }
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          final approvalType = data['approvalType']?.toString();
          final approvalId = data['approvalId']?.toString();
          final status = data['status']?.toString().toLowerCase() ?? '';
          final isApproved = status == 'approved' || status == 'rejected';
          final isPrivileged =
              AuthDataHelper.isAdminUser() || AuthDataHelper.isInternalUser();

          // Profile edit result — any user may receive this
          if (approvalType == 'profileEditRequest' && isApproved) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => EditUserProfileScreen()),
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              final ctx = navigatorKey.currentContext;
              if (ctx != null && ctx.mounted) {
                showSnackBar(
                  ctx,
                  status == 'approved'
                      ? 'Your profile update has been approved!'
                      : 'Your profile update was rejected',
                  backgroundColor:
                      status == 'approved' ? Colors.green : Colors.red,
                );
              }
            });
            return;
          }

          // Banner approval — admin/internal only
          if (approvalType == 'banner' && isApproved && isPrivileged) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const BannerScreen()),
            );
            return;
          }

          // Pending approval — admin/internal only
          if (!isApproved &&
              approvalId != null &&
              isPrivileged &&
              approvalType != null &&
              approvalType != 'notification') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder:
                    (_) => PendingApprovals(
                      approvalId: approvalId,
                      approvalType: approvalType,
                    ),
              ),
            );
            return;
          }

          // Everything else (regular push, 'notification' type, external users)
          // → open the Notification tab.
          NotificationServices.onOpenNotificationTab?.call();
        } catch (e) {
          debugPrint('⚠️ Local notification tap parse error: $e');
          NotificationServices.onOpenNotificationTab?.call();
        }
      },
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Local notifications initialized');
  }

  // ================= SETUP =================

  static Future<void> showPushAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    final service = NotificationServices();
    await service.initializeLocalNotifications();
    await service.showLocalNotification(
      title: title.isNotEmpty ? title : 'New Notification',
      body: body,
      payload: payload,
    );
  }

  void setupNotification(BuildContext context) async {
    if (!_hasFirebase) {
      debugPrint('⚠️ Firebase not initialized — skip FCM setup');
      return;
    }
    await initializeLocalNotifications();
    requestNotificationPermission();
    firebaseInit(context);
    setupInteractMessage(context);

    getToken().then((fcmToken) async {
      debugPrint("FCM Token: $fcmToken");
      if (fcmToken.isNotEmpty) {
        await FcmTokenService.syncToBackend(fcmToken: fcmToken);
      }
    });
  }

  // ================= TOKEN UPDATE =================

  Future<ApiResponse> updateFcmToken(String token, String fcmToken) async {
    final ok = await FcmTokenService.syncToBackend(fcmToken: fcmToken);
    return ApiResponse(
      statusCode: ok ? 200 : 500,
      message: ok ? 'OK' : 'FCM update failed',
      data: '',
    );
  }

  // ================= PERMISSION =================

  void requestNotificationPermission() async {
    if (!_hasFirebase) return;
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    debugPrint("FCM Permission Status: ${settings.authorizationStatus}");
  }

  // ================= SHOW LOCAL NOTIFICATION =================

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = _buildAndroidNotificationDetails();

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('✅ Local notification displayed');
  }

  // ================= FOREGROUND =================

  Future<void> firebaseInit(BuildContext context) async {
    if (!_hasFirebase) return;
    if (isIOS()) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("📩 Foreground Notification Received");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("📦 Message ID: ${message.messageId}");
      debugPrint("📦 Sent Time: ${message.sentTime}");

      // Log notification payload
      if (message.notification != null) {
        debugPrint("🔔 Notification Payload:");
        debugPrint("   Title: ${message.notification!.title}");
        debugPrint("   Body: ${message.notification!.body}");
        debugPrint("   Android: ${message.notification!.android}");
        debugPrint("   Apple: ${message.notification!.apple}");
      } else {
        debugPrint("⚠️ No notification payload found!");
      }

      // Log data payload
      if (message.data.isNotEmpty) {
        debugPrint("📋 Data Payload:");
        debugPrint("   ${jsonEncode(message.data)}");
      } else {
        debugPrint("⚠️ No data payload found!");
      }

      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

      // Parse notification data or fallback to title/body parsing
      Map<String, dynamic> notificationData = Map.from(message.data);

      // If data payload is empty, parse from title/body
      if (message.data.isEmpty && message.notification != null) {
        debugPrint("⚠️ Data payload empty, parsing from title/body");
        final parsed = _parseNotificationText(
          message.notification!.title ?? '',
          message.notification!.body ?? '',
        );

        if (parsed['type'] != null) {
          notificationData['approvalType'] = parsed['type'];
          notificationData['status'] = parsed['status'] ?? 'approved';
          if (parsed['id'] != null) {
            notificationData['approvalId'] = parsed['id'];
          }
          debugPrint(
            "✅ Parsed: type=${parsed['type']}, status=${parsed['status']}",
          );
        }
      }

      // Auto-refresh profile if it's an approved profile edit request
      final status = notificationData['status']?.toString().toLowerCase();
      final isApproved = status == 'approved' || status == 'rejected';
      final isProfileEdit =
          notificationData.containsKey('mobile') ||
          notificationData['approvalType'] == 'profileEditRequest';

      if (isApproved && isProfileEdit) {
        debugPrint("🔄 Auto-refreshing profile in background...");
        await _refreshUserProfile();
      }

      // Show local notification for foreground (handles both notification+data and data-only)
      final fgTitle =
          message.notification?.title ??
          notificationData['messageHeader']?.toString() ??
          notificationData['title']?.toString() ??
          '';
      final fgBody =
          message.notification?.body ??
          notificationData['messageBody']?.toString() ??
          notificationData['body']?.toString() ??
          '';
      if (fgTitle.isNotEmpty || fgBody.isNotEmpty) {
        await showLocalNotification(
          title: fgTitle.isNotEmpty ? fgTitle : 'New Notification',
          body: fgBody,
          payload: jsonEncode(notificationData),
        );
      }

      await _saveNotification(message);
    });
  }

  // ================= TOKEN =================

  Future<String> getToken() async {
    if (!_hasFirebase) return '';
    return await _messaging.getToken() ?? '';
  }

  // ================= BACKGROUND / TERMINATED =================

  Future<void> setupInteractMessage(BuildContext context) async {
    if (!_hasFirebase) return;
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      handleMessage(context, initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage event) {
      handleMessage(context, event);
    });
  }

  void handleMessage(BuildContext context, RemoteMessage remoteMessage) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("📩 Opened from notification tap");
      debugPrint("   msgId=${remoteMessage.messageId}");
      if (remoteMessage.data.isNotEmpty) {
        debugPrint("   data=${jsonEncode(remoteMessage.data)}");
      }

      // Always save to SQLite + update in-memory store first.
      await _saveNotification(remoteMessage);

      final data = remoteMessage.data;
      final isPrivileged =
          AuthDataHelper.isAdminUser() || AuthDataHelper.isInternalUser();

      // ── Detect type ─────────────────────────────────────────────────────
      String? approvalType = data['approvalType']?.toString();
      String? approvalId = data['approvalId']?.toString();
      String? status = data['status']?.toString();

      if (approvalType == null) {
        if (data.containsKey('bannerId')) {
          approvalType = 'banner';
          approvalId = data['bannerId']?.toString();
        } else if (data.containsKey('templateId')) {
          approvalType = 'template';
          approvalId = data['templateId']?.toString();
        } else if (data.containsKey('mobile')) {
          approvalType = 'profileEditRequest';
          approvalId = data['mobile']?.toString();
        }
        // notificationId → regular push for user; handled below
      }

      final statusLower = (status ?? '').toLowerCase();
      final isApproved = statusLower == 'approved' || statusLower == 'rejected';

      // ── Regular admin push notification ─────────────────────────────────
      // approvalType is null OR 'notification' → open Notification tab.
      if (approvalType == null || approvalType == 'notification') {
        debugPrint("🔔 Regular push → opening Notification tab");
        _openNotificationTab();
        return;
      }

      // ── Profile edit result (any user) ──────────────────────────────────
      if (approvalType == 'profileEditRequest') {
        if (isApproved) {
          debugPrint("🔄 Profile edit $statusLower — refreshing profile");
          await _refreshUserProfile();
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => EditUserProfileScreen()),
          );
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showSnackBar(
              ctx,
              statusLower == 'approved'
                  ? 'Your profile update has been approved!'
                  : 'Your profile update was rejected',
              backgroundColor:
                  statusLower == 'approved' ? Colors.green : Colors.red,
            );
          }
        }
        return;
      }

      // ── Admin / Internal only from here ──────────────────────────────────
      if (!isPrivileged) {
        _openNotificationTab();
        return;
      }

      if (isApproved) {
        if (approvalType == 'banner') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const BannerScreen()),
          );
        } else {
          _openNotificationTab();
        }
      } else if (approvalId != null) {
        // Pending approval item — open the approvals screen.
        debugPrint("🔗 Pending $approvalType → PendingApprovals");
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder:
                (_) => PendingApprovals(
                  approvalId: approvalId!,
                  approvalType: approvalType!,
                ),
          ),
        );
      }
    });
  }

  /// Switch to the Notification tab in MainScreen.
  /// MainScreen must register [onOpenNotificationTab] in its initState.
  void _openNotificationTab() {
    if (NotificationServices.onOpenNotificationTab != null) {
      NotificationServices.onOpenNotificationTab!();
    } else {
      debugPrint(
        '⚠️ onOpenNotificationTab not registered – navigation skipped',
      );
    }
  }

  // ================= REFRESH USER PROFILE =================

  /// Parse notification title/body to extract approval information
  /// Used as fallback when data payload is missing
  Map<String, String?> _parseNotificationText(String title, String body) {
    String? type;
    String? id;
    String? status;

    final titleLower = title.toLowerCase();
    final bodyLower = body.toLowerCase();

    // Detect type from title
    if (titleLower.contains('banner')) {
      type = 'banner';
    } else if (titleLower.contains('notification')) {
      type = 'notification';
    } else if (titleLower.contains('template')) {
      type = 'template';
    } else if (titleLower.contains('profile')) {
      type = 'profileEditRequest';
    }

    // Detect status from title or body
    if (titleLower.contains('approved') || bodyLower.contains('approved')) {
      status = 'approved';
    } else if (titleLower.contains('rejected') ||
        bodyLower.contains('rejected')) {
      status = 'rejected';
    } else if (titleLower.contains('pending') ||
        bodyLower.contains('pending')) {
      status = 'pending';
    }

    // Extract UUID/ID from body (common patterns: #id or "banner id" or just UUID)
    final uuidPattern = RegExp(
      r'#?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})',
      caseSensitive: false,
    );
    final match = uuidPattern.firstMatch(body);
    if (match != null) {
      id = match.group(1);
    }

    // Try to extract MongoDB ObjectId pattern if UUID not found
    if (id == null) {
      final objectIdPattern = RegExp(r'#?([a-f0-9]{24})', caseSensitive: false);
      final objectIdMatch = objectIdPattern.firstMatch(body);
      if (objectIdMatch != null) {
        id = objectIdMatch.group(1);
      }
    }

    return {'type': type, 'id': id, 'status': status};
  }

  Future<void> _refreshUserProfile() async {
    try {
      final token = AuthDataHelper.getToken();
      if (token.isEmpty) {
        debugPrint('⚠️ No token found, cannot refresh profile');
        return;
      }

      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.profile,
        token,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        final userJson = data['user'] ?? {};
        final userData = UserData.fromJson(userJson);

        // Update local storage with fresh data
        AuthDataHelper.saveUserData(userData);
        Get.find<EditProfileController>().initUserData();
        Get.find<EditProfileController>().getProfile();

        debugPrint('✅ User profile refreshed successfully');
        debugPrint('   Name: ${userData.firstName} ${userData.lastName}');
        debugPrint('   Email: ${userData.email}');

        AuthDataHelper.saveUserData(userData);
      } else {
        debugPrint('❌ Failed to refresh profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing profile: $e');
    }
  }

  // ================= SAVE TO DB =================

  static List<String>? _parseTargetUsers(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _saveNotification(RemoteMessage message) async {
    try {
      await _persistInboxFromFcm(message);
    } catch (e) {
      debugPrint("❌ Error saving notification: $e");
    }
  }

  static Future<void> _persistInboxFromFcm(RemoteMessage message) async {
    debugPrint('🔔 _persistInboxFromFcm: msgId=${message.messageId}');
    debugPrint('   data keys: ${message.data.keys.toList()}');
    debugPrint('   notification: title=${message.notification?.title}');

    final item = inboxItemFromFcm(message);
    if (item == null) {
      debugPrint('⚠️ _persistInboxFromFcm: no display content, skipping');
      return;
    }

    debugPrint(
      '💾 Saving inbox item: id=${item.id} header="${item.messageHeader}" '
      'status=${item.status} targets=${item.targetUsers}',
    );

    final isNew = await NotificationDB.instance.upsertInboxItem(item);
    debugPrint('💾 upsertInboxItem: isNew=$isNew');
    if (isNew) {
      NotificationInboxStore.instance.addNew(item);
    } else {
      await NotificationInboxStore.instance.reloadFromDatabase();
    }

    debugPrint('✅ Inbox saved: ${item.messageHeader} → ${item.targetUsers}');
  }

  static NotificationItem? inboxItemFromFcm(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    final header =
        (data['messageHeader'] ?? notification?.title ?? data['title'] ?? '')
            .toString();
    final body =
        (data['messageBody'] ?? notification?.body ?? data['body'] ?? '')
            .toString();
    if (header.trim().isEmpty && body.trim().isEmpty) return null;

    var targetUsers = _parseTargetUsers(
      data['targetUsers'] ?? data['targetUserTypes'] ?? data['target_users'],
    );
    if (targetUsers == null || targetUsers.isEmpty) {
      final role = AuthDataHelper.getUserType().trim();
      if (role.isNotEmpty) targetUsers = [role];
    }

    final notificationId = data['notificationId']?.toString().trim() ?? '';
    final stableId =
        notificationId.isNotEmpty
            ? notificationId
            : (data['_id']?.toString().trim().isNotEmpty == true
                ? data['_id'].toString()
                : message.messageId ??
                    DateTime.now().millisecondsSinceEpoch.toString());

    // FCM items are always "received" — device received them directly.
    // Using any other status (approved/active) can cause client-side filtering
    // to drop the item if targetUsers is mismatched.
    const status = 'received';

    final accountId = AuthDataHelper.getAccountId().trim();

    return NotificationItem(
      id: stableId,
      notificationId: notificationId,
      notificationTempId: data['notificationTempId']?.toString() ?? '',
      messageHeader: header,
      messageBody: body,
      link: data['link']?.toString() ?? '',
      scheduledDate: DateTime.now(),
      scheduledTime: DateTime.now(),
      targetUsers: targetUsers,
      isActive: true,
      isApproved: true,
      status: status,
      createdBy: data['createdBy']?.toString(),
      lastUpdatedBy: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      ownerAccountId: accountId.isNotEmpty ? accountId : null,
    );
  }
}

// ================= ANDROID BACKGROUND HANDLER =================

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await AppConfig.init();
  await FirebaseAppConfig.ensureInitialized();
  await PreferenceUtils.init();

  debugPrint("📩 Background Handler - Notification Received");
  debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  debugPrint("📦 Message ID: ${message.messageId}");
  debugPrint("📦 Sent Time: ${message.sentTime}");

  if (message.notification != null) {
    debugPrint("🔔 Notification Payload:");
    debugPrint("   Title: ${message.notification!.title}");
    debugPrint("   Body: ${message.notification!.body}");
  } else {
    debugPrint("⚠️ No notification payload — data-only FCM");
  }

  if (message.data.isNotEmpty) {
    debugPrint("📋 Data Payload: ${jsonEncode(message.data)}");
  } else {
    debugPrint("⚠️ No data payload found!");
  }

  debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

  // ── Save to SQLite ────────────────────────────────────────────────────────
  await NotificationServices._persistInboxFromFcm(message);

  // ── Show a banner when the app is in background / terminated ─────────────
  // Android only shows system banners for data-only FCM messages if the app
  // explicitly calls the local notifications plugin in the background isolate.
  try {
    final bgTitle =
        message.notification?.title ??
        message.data['messageHeader']?.toString() ??
        message.data['title']?.toString() ??
        '';
    final bgBody =
        message.notification?.body ??
        message.data['messageBody']?.toString() ??
        message.data['body']?.toString() ??
        '';

    if (bgTitle.isNotEmpty || bgBody.isNotEmpty) {
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@drawable/ic_notification');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );

      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(initSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap(
          '@drawable/ic_notification',
        ),
      );

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        bgTitle.isNotEmpty ? bgTitle : 'New Notification',
        bgBody,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode(message.data),
      );
      debugPrint('✅ Background banner shown: "$bgTitle"');
    }
  } catch (e) {
    debugPrint('⚠️ Background banner error: $e');
  }
}
