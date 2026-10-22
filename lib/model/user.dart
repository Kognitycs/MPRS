import 'dart:convert';

class User {
  final String username;
  final String firstName;
  final String lastName;
  final String businessEmail;
  final String mobile;
  final String country;
  final String password;
  final String confirmPassword;
  final String? imagePath;
  final String role;

  User({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.businessEmail,
    required this.mobile,
    required this.country,
    required this.password,
    required this.confirmPassword,
    this.imagePath,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      "username": username,
      "firstName": firstName,
      "lastName": lastName,
      "businessEmail": businessEmail,
      "mobile": mobile,
      "country": country,
      "password": password,
      "confirmPassword": confirmPassword,
      "imagePath": imagePath,
      "role": role,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      username: map['username'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      businessEmail: map['businessEmail'] ?? '',
      mobile: map['mobile'] ?? '',
      country: map['country'] ?? '',
      password: map['password'] ?? '',
      confirmPassword: map['confirmPassword'] ?? '',
      imagePath: map['imagePath'],
      role: map['role'] ?? 'External',
    );
  }

  String toJson() => jsonEncode(toMap());
  factory User.fromJson(String source) => User.fromMap(jsonDecode(source));
}
