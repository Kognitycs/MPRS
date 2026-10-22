import 'package:mprs_android/model/banner_item.dart';

class CreateBannerResponse {
  final String message;
  final BannerItem banner;

  CreateBannerResponse({required this.message, required this.banner});

  factory CreateBannerResponse.fromJson(Map<String, dynamic> json) {
    return CreateBannerResponse(
      message: json['message'],
      banner: BannerItem.fromJson(json['banner']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'banner': banner.toJson(),
    };
  }
}