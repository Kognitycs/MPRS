import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/firebase/firebase_app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/app_secrets.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/notification/fcm_topic_helper.dart';

/// Registers the device FCM token with the backend (after login and on refresh).
class FcmTokenService {
  FcmTokenService._();

  static bool _refreshListenerRegistered = false;

  static const String _prefFcmToken = 'fcm_device_token';
  static const String _prefSubscribedTopics = 'fcm_subscribed_topics';

  static Map<String, String> get _apiKeys => {
        ...AppConfig.apiHeaders,
        ...AppSecrets.apiKeyHeaders,
      };

  /// Call once after Firebase is initialized.
  static void registerTokenRefreshListener() {
    if (_refreshListenerRegistered || Firebase.apps.isEmpty) return;
    _refreshListenerRegistered = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed');
      syncToBackend(fcmToken: newToken);
    });
  }

  /// Fetches FCM token (if needed) and PATCHes it when user is logged in.
  /// Retries up to [_maxRetries] times if the token is not yet available.
  static const int _maxRetries = 3;

  static Future<bool> syncToBackend({String? fcmToken}) async {
    if (kIsWeb) return false;

    // If Firebase wasn't initialized at startup (e.g. Play Services temporarily
    // unavailable), try re-initializing it now before giving up.
    if (Firebase.apps.isEmpty) {
      try {
        await FirebaseAppConfig.ensureInitialized();
        debugPrint('🔥 Firebase re-initialized in FCM sync');
        FcmTokenService.registerTokenRefreshListener();
      } catch (e) {
        debugPrint('FCM sync skipped: Firebase not available ($e)');
        return false;
      }
    }

    if (Firebase.apps.isEmpty) {
      debugPrint('FCM sync skipped: Firebase still not available after retry');
      return false;
    }

    final authToken = AuthDataHelper.getToken();
    if (authToken.isEmpty) {
      debugPrint('FCM sync skipped: no auth token');
      return false;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM permission request error: $e');
    }

    try {
      String token = fcmToken?.trim() ?? '';

      // If no token provided, try fetching from Firebase with retries.
      if (token.isEmpty) {
        for (var attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            token =
                (await FirebaseMessaging.instance.getToken())?.trim() ?? '';
          } catch (_) {}
          if (token.isNotEmpty) break;
          if (attempt < _maxRetries) {
            debugPrint(
              '🔑 FCM getToken attempt $attempt failed — retrying in 3s...',
            );
            await Future<void>.delayed(const Duration(seconds: 3));
          }
        }
      }

      if (token.isEmpty) {
        debugPrint('❌ FCM sync failed: could not obtain FCM token after $_maxRetries attempts');
        return false;
      }

      final userType = AuthDataHelper.getUserType();
      debugPrint(
        '🔑 FCM sync START: userType=$userType token=${token.substring(0, token.length.clamp(0, 20))}...',
      );

      final response = await _patchFcmToken(authToken, token);
      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) {
        await PreferenceUtils.setString(_prefFcmToken, token);
        await _syncTopics(userType);
        debugPrint('✅ FCM token registered on server (status=${response.statusCode})');
      } else {
        // Still subscribe to topics so topic broadcasts work even if token
        // registration endpoint fails temporarily.
        await _syncTopics(userType);
        debugPrint(
          '❌ FCM token registration failed: status=${response.statusCode} msg=${response.message}',
        );
      }
      return ok;
    } catch (e, st) {
      debugPrint('FCM sync error: $e\n$st');
      return false;
    }
  }

  static Future<ApiResponse> _patchFcmToken(
    String authToken,
    String fcmToken,
  ) async {
    final body = jsonEncode({'fcmToken': fcmToken});

    if (AuthDataHelper.isAdminUser() || AuthDataHelper.isInternalUser()) {
      // Privileged users: only the admin endpoint is needed.
      debugPrint('🔑 Registering FCM token (admin endpoint)');
      final res = await HttpClientHelper.patchWithBearer(
        ApiConstants.updateFcmToken,
        authToken,
        headers: _apiKeys,
        body: body,
      );
      debugPrint('🔑 admin/update-fcm-token → ${res.statusCode}');
      return res;
    }

    // External / VIP / VVIP: register on BOTH endpoints.
    debugPrint('🔑 Registering FCM token on user + admin endpoints (External user)');

    final userRes = await HttpClientHelper.patchWithBearer(
      ApiConstants.userUpdateFcmToken,
      authToken,
      headers: _apiKeys,
      body: body,
    );
    debugPrint('🔑 user/update-fcm-token  → ${userRes.statusCode}');

    // Try admin endpoint WITH the External JWT first.
    final adminRes = await HttpClientHelper.patchWithBearer(
      ApiConstants.updateFcmToken,
      authToken,
      headers: _apiKeys,
      body: body,
    );
    debugPrint('🔑 admin/update-fcm-token (with JWT) → ${adminRes.statusCode}');

    final adminOk = adminRes.statusCode == 200 || adminRes.statusCode == 201;

    // If admin endpoint rejected the External JWT, try without any JWT —
    // service API keys only. The server may allow unauthenticated token
    // registration if the API keys are present.
    if (!adminOk) {
      debugPrint('🔑 admin/update-fcm-token → 403/err; retrying without JWT...');
      final adminNoJwtRes = await HttpClientHelper.patchWithApiKeysOnly(
        ApiConstants.updateFcmToken,
        body: body,
      );
      debugPrint('🔑 admin/update-fcm-token (no JWT) → ${adminNoJwtRes.statusCode}');
      final noJwtOk =
          adminNoJwtRes.statusCode == 200 || adminNoJwtRes.statusCode == 201;
      if (noJwtOk) {
        debugPrint('✅ FCM token registered in admin table (no-JWT path)');
      }
    }

    final userOk = userRes.statusCode == 200 || userRes.statusCode == 201;
    if (userOk) return userRes;
    if (adminOk) return adminRes;
    return adminRes;
  }

  /// Subscribe this device to role-based FCM topics for Firebase Admin broadcasts.
  static Future<void> _syncTopics(String userType) async {
    if (Firebase.apps.isEmpty) return;

    final desired = FcmTopicHelper.topicsForUserType(userType);
    final previous = PreferenceUtils.getStringList(_prefSubscribedTopics);

    for (final topic in previous) {
      if (!desired.contains(topic)) {
        try {
          await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
          debugPrint('🔕 Unsubscribed FCM topic: $topic');
        } catch (e) {
          debugPrint('⚠️ FCM unsubscribe failed ($topic): $e');
        }
      }
    }

    for (final topic in desired) {
      if (previous.contains(topic)) continue;
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        debugPrint('🔔 Subscribed FCM topic: $topic');
      } catch (e) {
        debugPrint('⚠️ FCM subscribe failed ($topic): $e');
      }
    }

    await PreferenceUtils.setStringList(_prefSubscribedTopics, desired);
  }

  /// Unsubscribe FCM topics on logout so the next user does not receive pushes
  /// meant for the previous account on the same device.
  static Future<void> clearOnLogout() async {
    if (Firebase.apps.isEmpty) return;

    final topics = PreferenceUtils.getStringList(_prefSubscribedTopics);
    for (final topic in topics) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (_) {}
    }
    await PreferenceUtils.remove(_prefSubscribedTopics);
    await PreferenceUtils.remove(_prefFcmToken);
  }

  /// Returns the last successfully synced device token, if any.
  static String get cachedToken => PreferenceUtils.getString(_prefFcmToken);
}
