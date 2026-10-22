import 'package:mprs_android/model/common/user_data.dart';

class SignupResponse {
  final String? message;
  final UserData? user;

  SignupResponse({this.message, this.user});

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      message: json['message'],
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'user': user?.toJson(),
    };
  }
}
