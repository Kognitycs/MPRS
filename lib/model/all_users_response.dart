import 'package:mprs_android/model/common/user_data.dart';

class AllUsersResponse {
  final int page;
  final int limit;
  final int totalRecords;
  final int totalPages;
  final List<UserData> data;

  AllUsersResponse({
    required this.page,
    required this.limit,
    required this.totalRecords,
    required this.totalPages,
    required this.data,
  });

  factory AllUsersResponse.fromJson(Map<String, dynamic> json) {
    return AllUsersResponse(
      page: json['page'],
      limit: json['limit'],
      totalRecords: json['totalRecords'],
      totalPages: json['totalPages'],
      data: (json['data'] as List).map((e) => UserData.fromJson(e)).toList(),
    );
  }
}
