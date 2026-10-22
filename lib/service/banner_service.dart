import 'dart:convert';

import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/model/api_response.dart';
import 'package:mprs_android/model/banner_list_response.dart';
import 'package:mprs_android/service/http_client_helper.dart';

class BannerService {
  static String listUrl({
    required int page,
    bool isActive = true,
    String? status,
    String? name,
    bool bustCache = true,
  }) {
    final params = <String, String>{
      'page': '$page',
      if (isActive) 'isActive': 'true',
      if (status != null && status.isNotEmpty) 'status': status,
      if (name != null && name.isNotEmpty) 'name': name,
      if (bustCache) '_': '${DateTime.now().millisecondsSinceEpoch}',
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '${ApiConstants.allBanners}?$query';
  }

  static Future<ApiResponse> fetchList({
    required int page,
    bool isActive = true,
    String? status,
    String? name,
  }) {
    return HttpClientHelper.getWithBearer(
      listUrl(
        page: page,
        isActive: isActive,
        status: status,
        name: name,
      ),
      AuthDataHelper.getToken(),
      headers: const {'Cache-Control': 'no-cache'},
    );
  }

  static Future<BannerListResponse?> fetchBannerListResponse({
    required int page,
    bool isActive = true,
    String? status,
    String? name,
  }) async {
    final response = await fetchList(
      page: page,
      isActive: isActive,
      status: status,
      name: name,
    );

    if (response.statusCode != 200) return null;

    final jsonBody = jsonDecode(response.data);
    return BannerListResponse.fromJson(jsonBody);
  }
}
