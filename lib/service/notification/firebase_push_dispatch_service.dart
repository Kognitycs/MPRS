import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/service/http_client_helper.dart';

class AdminPushDispatchResult {
  final bool ok;
  final int statusCode;
  final int tokenCount;
  final String message;

  const AdminPushDispatchResult({
    required this.ok,
    required this.statusCode,
    required this.tokenCount,
    required this.message,
  });

  static String userMessageForStatus(int statusCode) {
    if (statusCode == 404) {
      return 'Firebase push service is not deployed. Run deploy from the firebase folder '
          '(npx firebase-tools deploy --only functions:sendAdminPush).';
    }
    if (statusCode == 403) {
      return 'Firebase push service rejected the request (403).';
    }
    if (statusCode >= 500) {
      return 'Firebase push service error ($statusCode). Check Cloud Function logs.';
    }
    return 'Firebase push failed ($statusCode).';
  }
}

/// Dispatches admin push notifications via Firebase Admin Cloud Function.
class FirebasePushDispatchService {
  FirebasePushDispatchService._();

  static Future<AdminPushDispatchResult> dispatchAfterApproval({
    required String messageHeader,
    required String messageBody,
    required String notificationId,
    required List<String> targetUsers,
    String link = '',
  }) async {
    final result = await dispatchAdminPush(
      messageHeader: messageHeader,
      messageBody: messageBody,
      notificationId: notificationId,
      targetUsers: targetUsers,
      link: link,
    );
    if (!result.ok) {
      debugPrint(
        '⚠️ Client FCM dispatch failed (${result.statusCode}). '
        'Notification is still saved/approved on the server.',
      );
    }
    return result;
  }

  static Future<AdminPushDispatchResult> dispatchAdminPush({
    required String messageHeader,
    required String messageBody,
    required String notificationId,
    required List<String> targetUsers,
    List<String> tokens = const [],
    String link = '',
  }) async {
    try {
      final deviceTokens = <String>{
        ...tokens.where((t) => t.trim().isNotEmpty),
        ...await _fetchTargetDeviceTokens(targetUsers),
      };

      final body = jsonEncode({
        'messageHeader': messageHeader,
        'messageBody': messageBody,
        'notificationId': notificationId,
        'targetUsers': targetUsers,
        'tokens': deviceTokens.toList(),
        'link': link,
      });

      final response = await HttpClientHelper.post(
        ApiConstants.firebaseSendAdminPush,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final statusCode = response.statusCode;
      final ok = statusCode == 200 || statusCode == 201;
      final message = ok
          ? 'Push sent to ${deviceTokens.length} device token(s) and FCM topics.'
          : AdminPushDispatchResult.userMessageForStatus(statusCode);
      debugPrint(
        ok
            ? '✅ Firebase Admin push dispatched (${deviceTokens.length} token(s))'
            : '⚠️ Firebase Admin push failed: $statusCode — $message',
      );
      debugPrint('   URL: ${ApiConstants.firebaseSendAdminPush}');
      return AdminPushDispatchResult(
        ok: ok,
        statusCode: statusCode,
        tokenCount: deviceTokens.length,
        message: message,
      );
    } catch (e) {
      debugPrint('⚠️ Firebase Admin push error: $e');
      return const AdminPushDispatchResult(
        ok: false,
        statusCode: 0,
        tokenCount: 0,
        message: 'Could not reach Firebase push service.',
      );
    }
  }

  static Future<List<String>> _fetchTargetDeviceTokens(
    List<String> targetUsers,
  ) async {
    final token = AuthDataHelper.getToken();
    if (token.isEmpty || targetUsers.isEmpty) return const [];

    final targets =
        targetUsers.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    final tokens = <String>{};

    for (var page = 1; page <= 10; page++) {
      final url = '${ApiConstants.allUsers}?page=$page';
      final response = await HttpClientHelper.getWithBearer(url, token);
      if (response.statusCode != 200 && response.statusCode != 201) break;

      dynamic decoded = response.data;
      if (decoded is String) {
        try {
          decoded = jsonDecode(decoded);
        } catch (_) {
          break;
        }
      }

      final users = _extractUsers(decoded);
      if (users.isEmpty) break;

      for (final user in users) {
        if (user is! Map) continue;
        final map = Map<String, dynamic>.from(user);
        final role = (map['userType'] ?? map['UserType'] ?? '').toString().trim().toLowerCase();
        if (!targets.contains(role)) continue;

        final fcm = (map['fcmToken'] ?? map['FCMToken'] ?? '').toString().trim();
        if (fcm.isNotEmpty) tokens.add(fcm);
      }

      final totalPages = _readInt(
        decoded is Map ? decoded['totalPages'] : null,
        fallback: 1,
      );
      if (page >= totalPages) break;
    }

    debugPrint('🔔 Collected ${tokens.length} device token(s) for $targets');
    return tokens.toList();
  }

  static List<dynamic> _extractUsers(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    if (map['data'] is List) return map['data'] as List;
    if (map['data'] is Map && (map['data'] as Map)['data'] is List) {
      return (map['data'] as Map)['data'] as List;
    }
    if (map['users'] is List) return map['users'] as List;
    return const [];
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
