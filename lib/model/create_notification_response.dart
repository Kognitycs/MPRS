class CreateNotificationResponse {
  final String message;
  final NotificationData notification;

  CreateNotificationResponse({
    required this.message,
    required this.notification,
  });

  factory CreateNotificationResponse.fromJson(Map<String, dynamic> json) {
    final notificationJson = json['data'] ?? json['notification'];
    return CreateNotificationResponse(
      message: json['message'] ?? '',
      notification: NotificationData.fromJson(notificationJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {'message': message, 'notification': notification.toJson()};
  }
}

class NotificationData {
  final String notificationId;
  final String notificationTempId;
  final String messageHeader;
  final String messageBody;
  final String link;
  final DateTime scheduledDate;
  final DateTime scheduledTime;
  final bool isActive;
  final bool isApproved;
  final String status;
  final String lastUpdatedBy;
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int v;

  NotificationData({
    required this.notificationId,
    required this.notificationTempId,
    required this.messageHeader,
    required this.messageBody,
    required this.link,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.isActive,
    required this.isApproved,
    required this.status,
    required this.lastUpdatedBy,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      notificationId: json['notificationId']?.toString() ?? '',
      notificationTempId: json['notificationTempId']?.toString() ?? '',
      messageHeader: json['messageHeader']?.toString() ?? '',
      messageBody: json['messageBody']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      scheduledDate: _parseFlexibleDate(json['scheduledDate']),
      scheduledTime: _parseFlexibleDate(json['scheduledTime']),
      isActive: json['isActive'] == true,
      isApproved: json['isApproved'] == true,
      status: json['status']?.toString() ?? '',
      lastUpdatedBy: json['lastUpdatedBy']?.toString() ?? '',
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      createdAt: _parseFlexibleDate(json['createdAt']),
      updatedAt: _parseFlexibleDate(json['updatedAt']),
      v: json['__v'] is int ? json['__v'] as int : 0,
    );
  }

  static DateTime _parseFlexibleDate(dynamic value) {
    if (value == null) return DateTime.now();
    final text = value.toString().trim();
    if (text.isEmpty) return DateTime.now();

    try {
      return DateTime.parse(text);
    } catch (_) {}

    // Time-only values like "12:00" or "12:00:00"
    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (timeMatch != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
      );
    }

    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'notificationTempId': notificationTempId,
      'messageHeader': messageHeader,
      'messageBody': messageBody,
      'link': link,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime.toIso8601String(),
      'isActive': isActive,
      'isApproved': isApproved,
      'status': status,
      'lastUpdatedBy': lastUpdatedBy,
      '_id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      '__v': v,
    };
  }
}
