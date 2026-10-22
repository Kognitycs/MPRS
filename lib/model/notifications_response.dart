import 'package:mprs_android/model/notification_item.dart';

class NotificationsResponse {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int recordsInPage;
  final List<NotificationItem> data;

  NotificationsResponse({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.recordsInPage,
    required this.data,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalRecords: json['totalRecords'] ?? 0,
      recordsInPage: json['recordsInPage'] ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => NotificationItem.fromJson(e))
          .toList(),
    );
  }
}
