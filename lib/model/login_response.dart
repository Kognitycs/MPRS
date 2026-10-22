import 'package:mprs_android/model/common/user_data.dart';

class LoginResponse {
  final String message;
  final String token;
  final UserData? user; // user can be null

  LoginResponse({
    required this.message,
    required this.token,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'] ?? "",
      token: json['token'] ?? "",
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
    );
  }
}

class User {
  final String id;
  final String userId;
  final String username;
  final String firstName;
  final String lastName;

  final String email;
  final String? alternateEmail;
  final String mobile;
  final String? landlineNumber;
  final String? extentionNumber;

  final String? address;
  final String? country;
  final String? region;

  final bool termsAccepted;
  final String? companyName;
  final bool? activeRmsUser;

  final String? userType;
  final String? designation;
  final String? department;

  final String? deviceType;
  final String? profileImageUrl;

  final String? createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobile,
    this.alternateEmail,
    this.landlineNumber,
    this.extentionNumber,
    this.address,
    this.country,
    this.region,
    this.termsAccepted = false,
    this.companyName,
    this.activeRmsUser,
    this.userType,
    this.designation,
    this.department,
    this.deviceType,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? "",
      userId: json['userId'] ?? "",
      username: json['username'] ?? "",
      firstName: json['firstName'] ?? "",
      lastName: json['lastName'] ?? "",
      email: json['email'] ?? "",
      mobile: json['mobile'] ?? "",

      alternateEmail: json['alternateEmail'],
      landlineNumber: json['landlineNumber'],
      extentionNumber: json['extentionNumber'],
      address: json['address'],
      country: json['country'],
      region: json['region'],

      termsAccepted: json['termsAccepted'] ?? false,
      companyName: json['companyName'],
      activeRmsUser: json['Active_RMS_User'],
      userType: json['userType'],
      designation: json['designation'],
      department: json['department'],

      deviceType: json['deviceType'],
      profileImageUrl: json['profileImageUrl'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}
