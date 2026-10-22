/// Single response from `GET /api/admin/user/count` (`userType` optional).
class AdminUserCountResponse {
  final int count;
  final String? message;
  final String userType;

  const AdminUserCountResponse({
    this.count = 0,
    this.message,
    this.userType = '',
  });

  factory AdminUserCountResponse.fromJson(
    dynamic json, {
    String userType = '',
  }) {
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    return AdminUserCountResponse(
      count: _toInt(map['count']) ?? 0,
      message: map['message']?.toString(),
      userType: userType,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString().trim());
  }
}

/// Aggregated analytics for the report screen UI.
class AdminUserCountResult {
  final int allUsers;
  final int vipUsers;
  final int newCustomer;
  final int repeatedCustomer;

  const AdminUserCountResult({
    this.allUsers = 0,
    this.vipUsers = 0,
    this.newCustomer = 0,
    this.repeatedCustomer = 0,
  });

  static const empty = AdminUserCountResult();

  int get totalReach {
    final segmentSum = newCustomer + repeatedCustomer;
    if (segmentSum > 0) return segmentSum;
    return allUsers + vipUsers;
  }
}
