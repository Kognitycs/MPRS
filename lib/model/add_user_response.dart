import 'package:mprs_android/model/common/user_data.dart';

class AddUserResponse {
  final String? message;
  final UserData? user;
  final String? contactId;
  final String? accountId;

  AddUserResponse({
    this.message,
    this.user,
    this.contactId,
    this.accountId,
  });

  factory AddUserResponse.fromJson(Map<String, dynamic> json) {
    return AddUserResponse(
      message: json['message'],
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
      contactId: json['contactId'],
      accountId: json['accountId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'user': user?.toJson(),
      'contactId': contactId,
      'accountId': accountId,
    };
  }
}

