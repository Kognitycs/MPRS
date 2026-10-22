import 'package:mprs_android/model/common/user_data.dart';

class EditUserResponse {
  final String? message;
  final UserData? user;
  final String? contactId;
  final String? accountId;

  EditUserResponse({
    this.message,
    this.user,
    this.contactId,
    this.accountId,
  });

  factory EditUserResponse.fromJson(Map<String, dynamic> json) {
    return EditUserResponse(
      message: json['message'],
      user: json['data'] != null ? UserData.fromJson(json['data']) : null,
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

