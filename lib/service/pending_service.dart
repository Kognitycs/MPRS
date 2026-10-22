import 'dart:convert';

import 'package:mprs_android/model/pending_approval_item.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'dart:convert';

class PendingService {
  static String _buildEndpoint({int page = 1, String status = 'Pending'}) {
    return '${ApiConstants.getAllNotificationTemplates}?page=$page&status=$status';
  }

  /// Fetch pending approvals. If `token` is provided, uses bearer auth.
  /// If `type` is provided, fetches from the corresponding endpoint.
  /// Returns a map with 'items' and 'totalPages'
  static Future<Map<String, dynamic>> fetchPendingApprovals({
    String? token,
    PendingType? type,
    int page = 1,
    String status = 'Pending',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    ApiResponse resp;
    String url;

    // Build date parameters
    String dateParams = '';
    if (fromDate != null) {
      final fromDateStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      dateParams += '&fromDate=$fromDateStr';
    }
    if (toDate != null) {
      final toDateStr =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
      dateParams += '&toDate=$toDateStr';
    }

    if (type == PendingType.notification) {
      url =
          '${ApiConstants.getAllNotifications}?page=$page&status=$status$dateParams';
    } else if (type == PendingType.banner) {
      url = '${ApiConstants.allBanners}?page=$page&status=$status$dateParams';
    } else if (type == PendingType.profileEditRequest) {
      url = '${ApiConstants.allEditProfilesRequest}?page=$page$dateParams';
    } else {
      url = _buildEndpoint(page: page, status: status);
      if (dateParams.isNotEmpty) {
        url += dateParams;
      }
    }

    if (token == null) {
      resp = await HttpClientHelper.get(url);
    } else {
      resp = await HttpClientHelper.getWithBearer(url, token);
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      try {
        final decoded = json.decode(resp.data);
        List rawList = [];
        int totalPages = 1;

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          rawList = decoded['data'];
          totalPages = decoded['totalPages'] ?? 1;
        } else if (decoded is Map && decoded['items'] is List) {
          rawList = decoded['items'];
          totalPages = decoded['totalPages'] ?? 1;
        }

        final items =
            rawList.map<PendingApprovalItem>((e) {
              return PendingApprovalItem.fromJson(Map<String, dynamic>.from(e));
            }).toList();

        return {'items': items, 'totalPages': totalPages};
      } catch (e) {
        return {'items': <PendingApprovalItem>[], 'totalPages': 1};
      }
    }

    throw Exception(resp.message ?? 'Failed to fetch pending approvals');
  }

  /// Approve or reject a template by its templateId (PATCH /admin/notificationTemplateApproval/{templateId})
  static Future<ApiResponse> approveTemplate(
    String templateId,
    String status,
    String token,
    String comment,
  ) async {
    final url =
        '${ApiConstants.baseUrl}/admin/notificationTemplateApproval/$templateId';
    return await HttpClientHelper.patchWithBearer(
      url,
      token,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'comment': comment}),
    );
  }

  /// Approve or reject a notification by its notificationId (PATCH ${ApiConstants.updateNotification}/{notificationId})
  static Future<ApiResponse> approveNotification(
    String notificationId,
    String status,
    String token,
    String comment,
  ) async {
    final url = ApiConstants.notificationApproval(notificationId);
    return await HttpClientHelper.patchWithBearer(
      url,
      token,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'comment': comment}),
    );
  }

  /// Approve or reject a banner by its bannerId
  static Future<ApiResponse> approveBanner(
    String bannerId,
    String status,
    String token,
    String comment,
  ) async {
    final url = '${ApiConstants.baseUrl}/admin/bannerApproval/$bannerId';
    return await HttpClientHelper.patchWithBearer(
      url,
      token,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'comment': comment}),
    );
  }

  /// Approve or reject a profile edit request by mobile number
  static Future<ApiResponse> approveProfileEditRequest(
    String mobileNumber,
    String action,
    String token,
    String comment,
  ) async {
    final url = '${ApiConstants.baseUrl}/admin/profile/edit/approval';
    return await HttpClientHelper.patchWithBearer(
      url,
      token,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mobileNumber': mobileNumber,
        'action': action,
        'comment': comment,
      }),
    );
  }
}
