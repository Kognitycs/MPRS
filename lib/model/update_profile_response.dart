import 'package:mprs_android/model/common/user_data.dart';

class UpdateProfileResponse {
  final String message;
  final String token;
  final UserData? user; // user can be null

  UpdateProfileResponse({
    required this.message,
    required this.token,
    this.user,
  });

  factory UpdateProfileResponse.fromJson(Map<String, dynamic> json) {
    return UpdateProfileResponse(
      message: json['message'] ?? "",
      token: json['token'] ?? "",
      user: json['data'] != null ? UserData.fromJson(json['data']) : null,
    );
  }
}
