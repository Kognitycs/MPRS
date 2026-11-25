import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/utils/api_error_utils.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/sales_account_directory.dart';

/// Identity fields some backends require alongside `accountId` (avoids 500 on tag-only).
class AdminAccountTagIdentity {
  final String? mobile;
  final String? username;
  final String? email;

  const AdminAccountTagIdentity({this.mobile, this.username, this.email});
}

/// Persists Internal user's optional Salesforce account tag via admin update-user.
///
/// Backend accepts **multipart PATCH** only (JSON returns "Invalid headers").
class AdminUserAccountTagService {
  static Future<({bool ok, String? errorMessage})> syncForUser({
    required String userId,
    String? mongoId,
    required String? accountId,
    List<SalesAccountChoice>? accountChoices,
    AdminAccountTagIdentity? identity,
  }) async {
    final sendId = SalesAccountDirectory.canonicalAccountIdForAdminTag(
      accountId,
      choices: accountChoices,
    );
    if (accountId != null &&
        accountId.trim().isNotEmpty &&
        sendId == null) {
      return (
        ok: false,
        errorMessage:
            'Invalid account id. Open the list for this email and pick again.',
      );
    }

    final userNumber = userId.trim();
    final mongo = mongoId?.trim() ?? '';
    if (userNumber.isEmpty && mongo.isEmpty) {
      return (ok: false, errorMessage: 'Missing user id for account tag');
    }

    final token = AuthDataHelper.getToken().trim();
    if (token.isEmpty) {
      return (ok: false, errorMessage: 'Not signed in');
    }

    debugPrint(
      'AdminUserAccountTag: canonical=$sendId raw=${accountId?.trim()}',
    );

    final variants = _multipartFieldAttempts(sendId, identity);
    String? lastMessage;
    var attempt = 0;

    Future<({bool ok, bool notFound})> runFor(String targetUserId) async {
      final url = '${ApiConstants.updateUser}/$targetUserId';
      var sawNotFound = false;
      for (final fields in variants) {
        attempt++;
        try {
          final response = await HttpClientHelper.patchWithMultipart(
            url,
            token,
            fields: fields,
          );
          final code = response.statusCode;
          if (code >= 200 && code < 300) {
            debugPrint(
              'AdminUserAccountTag: success userId=$targetUserId '
              'attempt=$attempt fields=${fields.keys.join(",")}',
            );
            return (ok: true, notFound: false);
          }
          lastMessage = parseApiErrorMessage(
            response.data,
            fallback: response.message ?? 'Could not update tag',
          );
          debugPrint(
            'AdminUserAccountTag: userId=$targetUserId attempt=$attempt '
            'HTTP $code fields=${fields.keys.join(",")} ${response.data}',
          );
          if (code == 404) {
            sawNotFound = true;
            break;
          }
        } catch (e) {
          lastMessage = e.toString();
          debugPrint('AdminUserAccountTag: attempt=$attempt error: $e');
        }
      }
      return (ok: false, notFound: sawNotFound);
    }

    if (userNumber.isNotEmpty) {
      final first = await runFor(userNumber);
      if (first.ok) return (ok: true, errorMessage: null);
      if (first.notFound &&
          mongo.isNotEmpty &&
          mongo != userNumber) {
        final second = await runFor(mongo);
        if (second.ok) return (ok: true, errorMessage: null);
      }
    } else if (mongo.isNotEmpty) {
      final only = await runFor(mongo);
      if (only.ok) return (ok: true, errorMessage: null);
    }

    final technical = lastMessage?.trim() ?? '';
    final isServerError = technical.toLowerCase().contains('internal server');
    final message = isServerError
        ? 'Tagged account could not be saved on the server. '
            'Share this with support: PATCH admin/update-user with accountId '
            'returns 500 for Internal users (id=$userNumber, account=$sendId).'
        : (lastMessage ?? 'Could not update tagged account');

    return (ok: false, errorMessage: message);
  }

  static List<Map<String, String>> _multipartFieldAttempts(
    String? sendId,
    AdminAccountTagIdentity? identity,
  ) {
    final out = <Map<String, String>>[];

    void add(Map<String, String> fields) {
      out.add(fields);
    }

    final mobile = identity?.mobile?.trim() ?? '';
    final username = identity?.username?.trim() ?? '';
    final email = identity?.email?.trim() ?? '';
    final hasIdentity = mobile.isNotEmpty && username.isNotEmpty;

    if (sendId == null || sendId.isEmpty) {
      add({'accountId': ''});
      if (hasIdentity) {
        add({
          'mobile': mobile,
          'username': username,
          'userType': 'Internal',
          'accountId': '',
        });
      }
      return out;
    }

    final id = sendId.trim();
    add({'accountId': id});
    add({'accountId': id, 'userType': 'Internal'});
    add({'taggedAccountId': id});
    add({'taggedAccountId': id, 'userType': 'Internal'});
    add({'taggedAccounts': jsonEncode([id])});

    if (hasIdentity) {
      add({
        'mobile': mobile,
        'username': username,
        'userType': 'Internal',
        'accountId': id,
      });
      if (email.isNotEmpty) {
        add({
          'mobile': mobile,
          'username': username,
          'email': email,
          'userType': 'Internal',
          'accountId': id,
        });
      }
    }

    return out;
  }
}