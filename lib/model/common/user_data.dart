import 'dart:io';

class UserData {
  final String? userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? designation;
  final String? department;
  final String? email;
  final String? alternateEmail;
  final String? mobile;
  final String? alternateMobile;
  final String? landlineNumber;
  final String? extentionNumber;
  final String? address;
  final String? country;
  final String? region;
  final bool? termsAccepted;
  final bool? isActive;
  final String? companyName;
  final bool? activeRmsUser;
  final String? userType;
  final String? deviceType;
  final String? profileImageUrl; // Network URL
  final File? profileImageFile; // Local file for upload
  final String? fcmToken; // New field
  final String? lastUpdatedBy; // New field
  final String? id;
  final String? gstin;
  final String? createdAt;
  final String? updatedAt;
  final int? v;
  final String? accountId; // Salesforce account ID
  final String? contactId; // salesforce contact ID
  UserData({
    this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.designation,
    this.department,
    this.email,
    this.alternateEmail,
    this.mobile,
    this.alternateMobile,
    this.landlineNumber,
    this.extentionNumber,
    this.address,
    this.country,
    this.region,
    this.termsAccepted,
    this.isActive,
    this.companyName,
    this.activeRmsUser,
    this.userType,
    this.deviceType,
    this.profileImageUrl,
    this.profileImageFile,
    this.fcmToken,
    this.lastUpdatedBy,
    this.id,
    this.gstin,
    this.createdAt,
    this.updatedAt,
    this.v,
    this.accountId,
    this.contactId,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['userId'],
      username: json['username'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      designation: json['designation'],
      department: json['department'],
      email: json['email'],
      alternateEmail: json['alternateEmail'],
      mobile: json['mobile'],
      alternateMobile: json['alternateMobile'],
      landlineNumber: json['landlineNumber'],
      extentionNumber: json['extentionNumber'],
      address: json['address'],
      country: json['country'],
      region: json['region'],
      termsAccepted: json['termsAccepted'],
      isActive: json['isActive'],
      companyName: json['companyName'],
      activeRmsUser: json['Active_RMS_User'],
      userType: json['userType'],
      deviceType: json['deviceType'],
      profileImageUrl: json['profileImageUrl'],
      profileImageFile: null,
      fcmToken: json['fcmToken'],
      lastUpdatedBy: json['lastUpdatedBy'],
      id: json['_id'],
      gstin: json['gstin'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      v: json['__v'],
      accountId: json['accountId'],
      contactId: json['contactId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'designation': designation,
      'department': department,
      'email': email,
      'alternateEmail': alternateEmail,
      'mobile': mobile,
      'alternateMobile': alternateMobile,
      'landlineNumber': landlineNumber,
      'extentionNumber': extentionNumber,
      'address': address,
      'country': country,
      'region': region,
      'termsAccepted': termsAccepted,
      'isActive': isActive,
      'companyName': companyName,
      'Active_RMS_User': activeRmsUser,
      'userType': userType,
      'deviceType': deviceType,
      'profileImageUrl': profileImageUrl,
      'fcmToken': fcmToken,
      'lastUpdatedBy': lastUpdatedBy,
      '_id': id,
      'gstin': gstin,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      '__v': v,
      'accountId': accountId,
      'contactId': contactId,
      // profileImageFile is not included in JSON
    };
  }
}
