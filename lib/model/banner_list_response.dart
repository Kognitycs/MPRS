import 'package:mprs_android/model/banner_item.dart';

class BannerListResponse {
  final int currentPage;
  final int totalPages;
  final int limit;
  final int totalRecords;
  final int recordsInPage;
  final List<BannerItem> data;

  BannerListResponse({
    required this.currentPage,
    required this.totalPages,
    required this.limit,
    required this.totalRecords,
    required this.recordsInPage,
    required this.data,
  });

  factory BannerListResponse.fromJson(Map<String, dynamic> json) {
    return BannerListResponse(
      currentPage: json['currentPage'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      limit: json['limit'] ?? 0,
      totalRecords: json['totalRecords'] ?? 0,
      recordsInPage: json['recordsInPage'] ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => BannerItem.fromJson(e))
          .toList(),
    );
  }
}
