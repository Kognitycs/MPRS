import 'dart:convert';

class NotificationItem {
  final String id;
  final String notificationId;
  final String notificationTempId;
  final String messageHeader;
  final String messageBody;
  final String link;
  final DateTime scheduledDate;
  final DateTime scheduledTime;
  final List<String>? targetUsers;
  final bool isActive;
  final bool isApproved;
  final String status;
  final String? createdBy;
  final String? createdByName;
  final String lastUpdatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerAccountId;

  NotificationItem({
    required this.id,
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
    required this.createdBy,
    this.createdByName,
    required this.lastUpdatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.targetUsers,
    this.ownerAccountId,
  });

  String get displayTitle {
    final h = messageHeader.trim();
    if (h.isNotEmpty) return h;
    final b = messageBody.trim();
    if (b.isNotEmpty) {
      return b.length > 80 ? '${b.substring(0, 80)}…' : b;
    }
    return 'Notification';
  }

  String get displayBody {
    final h = messageHeader.trim();
    final b = messageBody.trim();
    if (b.isEmpty) return '';
    if (h.isNotEmpty && b == h) return '';
    return b;
  }

  bool get hasDisplayContent =>
      messageHeader.trim().isNotEmpty || messageBody.trim().isNotEmpty;

  /// Shipment tracking alerts saved with id `shipment_*`.
  bool get isShipmentAlert => id.startsWith('shipment_');

  /// Admin push / template notification (not shipment tracking).
  bool get isAdminPush => !isShipmentAlert && hasDisplayContent;

  /// Time shown on the notification card (when it first arrived on device).
  DateTime get arrivedAt => statusUpdatedAt;

  /// When the shipment status changed (from Salesforce date on the timeline).
  DateTime get statusUpdatedAt {
    try {
      final decoded = jsonDecode(link);
      if (decoded is Map && decoded['statusUpdatedAt'] != null) {
        return DateTime.parse(decoded['statusUpdatedAt'].toString());
      }
    } catch (_) {}
    return createdAt;
  }

  String get statusStepTitle {
    try {
      final decoded = jsonDecode(link);
      if (decoded is Map && decoded['statusTitle'] != null) {
        return decoded['statusTitle'].toString().trim();
      }
    } catch (_) {}
    return '';
  }

  /// Shipment alerts are scoped to [accountId] in [link] JSON.
  bool belongsToAccount(String accountId) {
    if (accountId.isEmpty) return true;
    if (!isShipmentAlert) return true;
    final owner = ownerAccountId?.trim() ?? _accountIdFromLink();
    if (owner.isEmpty) return true;
    return owner == accountId;
  }

  String _accountIdFromLink() {
    try {
      final decoded = jsonDecode(link);
      if (decoded is Map) {
        return decoded['accountId']?.toString().trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Inbox visibility for role (External, VIP, VVIP) — admin push + API rows.
  bool isVisibleToUserType(String userType, {bool serverPrefiltered = false}) {
    final statusLower = status.trim().toLowerCase();
    if (statusLower == 'pending' || statusLower == 'rejected') return false;

    // Persisted shipment + FCM inbox — always show (even before userType loads on login).
    if (statusLower == 'received' || isShipmentAlert) return true;

    final role = userType.trim().toLowerCase();
    // Still show saved admin rows while profile loads after login.
    if (role.isEmpty) return hasDisplayContent;

    if (!isActive && (isShipmentAlert || notificationId.trim().isEmpty)) {
      return false;
    }

    final delivered = isApproved ||
        statusLower == 'sent' ||
        statusLower == 'approved' ||
        statusLower == 'active' ||
        statusLower == 'delivered' ||
        statusLower.isEmpty;
    if (!delivered) return false;

    final targets = targetUsers;
    if (serverPrefiltered ||
        targets == null ||
        targets.isEmpty) {
      return true;
    }

    return _targetsRole(role);
  }

  bool _targetsRole(String role) {
    final targets = targetUsers;
    if (targets == null || targets.isEmpty) return false;
    return targets.any((t) {
      final target = t.trim().toLowerCase();
      if (target == 'all') return true;
      return target == role;
    });
  }

  static List<String>? _parseTargetUsers(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    // Properly JSON-decode arrays like ["External"] or ["External","VIP"]
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static bool _parseIsActive(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['_id'] ?? json['id'] ?? json['notificationId'] ?? '')
          .toString(),
      notificationId: json['notificationId'] ?? '',
      notificationTempId: json['notificationTempId'] ?? '',
      messageHeader: (json['messageHeader'] ??
              json['title'] ??
              json['header'] ??
              '')
          .toString(),
      messageBody: (json['messageBody'] ??
              json['body'] ??
              json['message'] ??
              '')
          .toString(),
      link: json['link'] ?? '',
      scheduledDate: _parseDate(json['scheduledDate']),
      scheduledTime: _parseDate(json['scheduledTime']),
      targetUsers: _parseTargetUsers(
        json['targetUsers'] ??
            json['targetUserTypes'] ??
            json['targetingUsers'] ??
            json['targetingUser'],
      ),
      isActive: _parseIsActive(json['isActive']),
      isApproved: _parseBool(json['isApproved']),
      status: json['status'] ?? '',
      createdBy:
          json["createdBy"] is Map
              ? json["createdBy"]["_id"]
              : json["createdBy"],
      createdByName:
          json["createdBy"] is Map
              ? "${json["createdBy"]["firstName"] ?? ''} ${json["createdBy"]["lastName"] ?? ''}"
                  .trim()
              : null,
      lastUpdatedBy: json['lastUpdatedBy'] ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      ownerAccountId: json['ownerAccountId']?.toString(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notificationId': notificationId,
      'notificationTempId': notificationTempId,
      'messageHeader': messageHeader,
      'messageBody': messageBody,
      'link': link,
      'scheduledDate': scheduledDate.toIso8601String(),
      'scheduledTime': scheduledTime.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'isApproved': isApproved ? 1 : 0,
      'status': status,
      'createdBy': createdBy,
      // Exclude createdByName as it's not in the database schema
      // 'createdByName': createdByName,
      'lastUpdatedBy': lastUpdatedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'targetUsers': targetUsers?.join(','),
      'ownerAccountId': ownerAccountId,
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'],
      notificationId: map['notificationId'],
      notificationTempId: map['notificationTempId'],
      messageHeader: map['messageHeader'],
      messageBody: map['messageBody'],
      link: map['link'],
      scheduledDate: DateTime.parse(map['scheduledDate']),
      scheduledTime: DateTime.parse(map['scheduledTime']),
      isActive: map['isActive'] == 1,
      isApproved: map['isApproved'] == 1,
      status: map['status'],
      createdBy: map['createdBy'],
      createdByName: map['createdByName'],
      lastUpdatedBy: map['lastUpdatedBy'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      targetUsers:
          map['targetUsers'] != null &&
                  map['targetUsers'] is String &&
                  (map['targetUsers'] as String).isNotEmpty
              ? (map['targetUsers'] as String).split(',')
              : null,
      ownerAccountId: map['ownerAccountId']?.toString(),
    );
  }
}
