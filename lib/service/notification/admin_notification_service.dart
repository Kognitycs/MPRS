import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/model/create_notification_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/notification/firebase_push_dispatch_service.dart';
import 'package:mprs_android/service/pending_service.dart';

/// Payload for `POST /admin/createNotification`.
class CreatePushNotificationRequest {
  final String? notificationTempId;
  final String messageHeader;
  final String messageBody;
  final String link;
  final String scheduledDate;
  final String scheduledTime;
  final List<String> targetUsers;

  const CreatePushNotificationRequest({
    this.notificationTempId,
    required this.messageHeader,
    required this.messageBody,
    this.link = '',
    required this.scheduledDate,
    required this.scheduledTime,
    required this.targetUsers,
  });

  Map<String, dynamic> toJson() => {
        if (notificationTempId != null &&
            notificationTempId!.trim().isNotEmpty)
          'notificationTempId': notificationTempId!.trim(),
        'messageHeader': messageHeader.trim(),
        'messageBody': messageBody.trim(),
        'link': link.trim(),
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'targetUsers': targetUsers,
      };
}

class CreateAndPushResult {
  final bool created;
  final bool approved;
  final bool fcmDispatched;
  final int fcmStatusCode;
  final String notificationId;
  final String serverMessage;
  final String fcmMessage;

  const CreateAndPushResult({
    required this.created,
    required this.approved,
    required this.fcmDispatched,
    required this.fcmStatusCode,
    required this.notificationId,
    required this.serverMessage,
    required this.fcmMessage,
  });

  String get userMessage {
    if (!created) return serverMessage;
    if (!approved) {
      return '$serverMessage Approval is required before users receive the push.';
    }
    if (fcmDispatched) {
      return 'Notification created and push sent to target users.';
    }
    return 'Notification saved on server. $fcmMessage';
  }
}

/// Admin: create notification on API, approve, then dispatch FCM.
class AdminNotificationService {
  AdminNotificationService._();

  /// `POST /admin/createNotification` → approve → Cloud Function FCM dispatch.
  static Future<CreateAndPushResult> createAndPush(
    CreatePushNotificationRequest request,
  ) async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      return const CreateAndPushResult(
        created: false,
        approved: false,
        fcmDispatched: false,
        fcmStatusCode: 0,
        notificationId: '',
        serverMessage: 'Please log in again.',
        fcmMessage: '',
      );
    }

    debugPrint('🔔 POST ${ApiConstants.createNotification}');

    final createResp = await HttpClientHelper.postWithBearerNew(
      ApiConstants.createNotification,
      token,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    debugPrint(
      '🔔 createNotification → ${createResp.statusCode} ${createResp.data}',
    );

    if (createResp.statusCode != 200 && createResp.statusCode != 201) {
      return CreateAndPushResult(
        created: false,
        approved: false,
        fcmDispatched: false,
        fcmStatusCode: 0,
        notificationId: '',
        serverMessage: parseApiErrorMessage(
          createResp.data,
          fallback: 'Create failed (${createResp.statusCode})',
        ),
        fcmMessage: '',
      );
    }

    final parsed = _parseCreateResponse(createResp.data);
    final notification = parsed?.notification;
    final notificationId = notification?.notificationId.trim() ?? '';

    if (notificationId.isEmpty) {
      return CreateAndPushResult(
        created: true,
        approved: false,
        fcmDispatched: false,
        fcmStatusCode: 0,
        notificationId: '',
        serverMessage: parsed?.message.isNotEmpty == true
            ? parsed!.message
            : 'Notification saved, but no notification id was returned.',
        fcmMessage: '',
      );
    }

    final alreadyApproved = notification?.isApproved == true ||
        notification?.status.trim().toLowerCase() == 'approved';

    var approved = alreadyApproved;
    if (!alreadyApproved) {
      final approveResp = await PendingService.approveNotification(
        notificationId,
        'Approved',
        token,
        '',
      );
      approved =
          approveResp.statusCode == 200 || approveResp.statusCode == 201;
      if (!approved) {
        return CreateAndPushResult(
          created: true,
          approved: false,
          fcmDispatched: false,
          fcmStatusCode: 0,
          notificationId: notificationId,
          serverMessage: parseApiErrorMessage(
            approveResp.data,
            fallback:
                approveResp.message ??
                'Approve failed (${approveResp.statusCode})',
          ),
          fcmMessage: '',
        );
      }
    }

    final dispatch = await FirebasePushDispatchService.dispatchAfterApproval(
      messageHeader: request.messageHeader,
      messageBody: request.messageBody,
      notificationId: notificationId,
      targetUsers: request.targetUsers,
      link: request.link,
    );

    return CreateAndPushResult(
      created: true,
      approved: true,
      fcmDispatched: dispatch.ok,
      fcmStatusCode: dispatch.statusCode,
      notificationId: notificationId,
      serverMessage: parsed?.message.isNotEmpty == true
          ? parsed!.message
          : 'Notification created.',
      fcmMessage: dispatch.message,
    );
  }

  /// Approve an existing pending notification and dispatch FCM.
  static Future<CreateAndPushResult> approveAndPush({
    required String notificationId,
    required String messageHeader,
    required String messageBody,
    required List<String> targetUsers,
    String link = '',
  }) async {
    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty || notificationId.trim().isEmpty) {
      return const CreateAndPushResult(
        created: false,
        approved: false,
        fcmDispatched: false,
        fcmStatusCode: 0,
        notificationId: '',
        serverMessage: 'Invalid notification or session.',
        fcmMessage: '',
      );
    }

    final approveResp = await PendingService.approveNotification(
      notificationId,
      'Approved',
      token,
      '',
    );

    if (approveResp.statusCode != 200 && approveResp.statusCode != 201) {
      return CreateAndPushResult(
        created: true,
        approved: false,
        fcmDispatched: false,
        fcmStatusCode: 0,
        notificationId: notificationId,
        serverMessage: parseApiErrorMessage(
          approveResp.data,
          fallback:
              approveResp.message ??
              'Approve failed (${approveResp.statusCode})',
        ),
        fcmMessage: '',
      );
    }

    final dispatch = await FirebasePushDispatchService.dispatchAfterApproval(
      messageHeader: messageHeader,
      messageBody: messageBody,
      notificationId: notificationId,
      targetUsers: targetUsers,
      link: link,
    );

    return CreateAndPushResult(
      created: true,
      approved: true,
      fcmDispatched: dispatch.ok,
      fcmStatusCode: dispatch.statusCode,
      notificationId: notificationId,
      serverMessage: 'Notification approved.',
      fcmMessage: dispatch.message,
    );
  }

  /// Dispatch FCM after the notification is already approved on the server.
  static Future<AdminPushDispatchResult> dispatchPush({
    required String messageHeader,
    required String messageBody,
    required String notificationId,
    required List<String> targetUsers,
    String link = '',
  }) {
    return FirebasePushDispatchService.dispatchAfterApproval(
      messageHeader: messageHeader,
      messageBody: messageBody,
      notificationId: notificationId,
      targetUsers: targetUsers,
      link: link,
    );
  }

  static CreateNotificationResponse? _parseCreateResponse(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map<String, dynamic>) return null;
      return CreateNotificationResponse.fromJson(decoded);
    } catch (e, st) {
      debugPrint('🔔 createNotification parse error: $e\n$st');
      return null;
    }
  }
}
