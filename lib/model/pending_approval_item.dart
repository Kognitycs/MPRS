import 'package:flutter/foundation.dart';

enum PendingType { notification, template, user, banner, profileEditRequest }

class PendingApprovalItem {
  final String id;
  final String? mongoId; // Store MongoDB _id for matching
  final PendingType type;
  final String title;
  final String description;
  final DateTime createdAt;
  // Template / notification specific fields
  final String? templateId;
  final String? templateType;
  final String? templateName;
  final String? templateHeader;
  final String? body;
  final String? createdBy;
  final String? createdByName;
  final bool? isActive;
  final bool? isApproved;
  final String? status;
  final DateTime? updatedAt;
  final String? updatedBy;
  // Notification specific
  final String? notificationId;
  final String? notificationTempId;
  final String? messageHeader;
  final String? messageBody;
  final String? link;
  final DateTime? scheduledDate;
  final DateTime? scheduledTime;
  final List<String>? targetUsers;
  final String? lastUpdatedBy;
  // Banner-specific fields
  final String? bannerId;
  final String? bannerName;
  final String? bannerTitle;
  final String? bannerImageUrl;
  final String? bannerUrl;
  // Profile edit request specific fields
  final String? profileId;
  final String? mobile;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? alternateEmail;
  final String? alternateMobile;
  final String? companyName;
  final String? department;
  final String? designation;
  final String? profileImageUrl;
  final String? address;
  final String? country;
  final String? region;
  final String? landlineNumber;
  final String? extentionNumber;
  final bool? activeRmsUser;

  PendingApprovalItem({
    required this.id,
    this.mongoId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.templateId,
    this.templateType,
    this.templateName,
    this.templateHeader,
    this.body,
    this.createdBy,
    this.createdByName,
    this.isActive,
    this.isApproved,
    this.status,
    this.updatedAt,
    this.updatedBy,
    this.notificationId,
    this.notificationTempId,
    this.messageHeader,
    this.messageBody,
    this.link,
    this.scheduledDate,
    this.scheduledTime,
    this.targetUsers,
    this.lastUpdatedBy,
    this.bannerId,
    this.bannerName,
    this.bannerTitle,
    this.bannerImageUrl,
    this.bannerUrl,
    this.profileId,
    this.mobile,
    this.firstName,
    this.lastName,
    this.email,
    this.alternateEmail,
    this.alternateMobile,
    this.companyName,
    this.department,
    this.designation,
    this.profileImageUrl,
    this.address,
    this.country,
    this.region,
    this.landlineNumber,
    this.extentionNumber,
    this.activeRmsUser,
  });

  factory PendingApprovalItem.fromJson(Map<String, dynamic> json) {
    // Determine type using templateId presence for templates
    final String rawType =
        (json['type'] ?? json['templateType'] ?? json['status'] ?? '')
            .toString()
            .toLowerCase();
    PendingType type;

    if (json['mobile'] != null &&
        json['firstName'] != null &&
        json['lastUpdatedBy'] != null) {
      type = PendingType.profileEditRequest;
    } else if (json['bannerId'] != null || json['bannerImageUrl'] != null) {
      type = PendingType.banner;
    } else if (json['templateId'] != null) {
      // If templateId exists, treat as template regardless of templateType value
      type = PendingType.template;
    } else {
      switch (rawType) {
        case 'notification':
        case 'notifications':
          type = PendingType.notification;
          break;
        case 'template':
        case 'templates':
        case 'promotional':
        case 'transactional':
          type = PendingType.template;
          break;
        case 'user':
        case 'users':
          type = PendingType.user;
          break;
        default:
          type = PendingType.notification;
      }
    }

    DateTime createdAt;
    final createdVal =
        json['createdAt'] ??
        json['created_at'] ??
        json['created'] ??
        json['createdat'] ??
        json['createdAt'];
    if (createdVal is String) {
      try {
        createdAt = DateTime.parse(createdVal);
      } catch (_) {
        createdAt = DateTime.now();
      }
    } else if (createdVal is int) {
      // assume epoch millis
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdVal);
    } else {
      createdAt = DateTime.now();
    }

    // Map fields for different API shapes (templates vs generic)
    final String id =
        (json['bannerId'] ??
                json['notificationId'] ??
                json['templateId'] ??
                json['id'] ??
                json['_id'] ??
                json['template_id'] ??
                '')
            .toString();

    // Build title based on type
    String title;
    if (type == PendingType.profileEditRequest) {
      final firstName = json['firstName']?.toString() ?? '';
      final lastName = json['lastName']?.toString() ?? '';
      title = 'Profile Update - $firstName $lastName'.trim();
      if (title == 'Profile Update -') {
        title = 'Profile Update Request';
      }
    } else {
      title =
          (json['title'] ??
                  json['templateName'] ??
                  json['template_name'] ??
                  json['messageHeader'] ??
                  json['message_header'] ??
                  '')
              .toString();
    }

    // Build description based on type
    String description;
    if (type == PendingType.profileEditRequest) {
      final email = json['email']?.toString() ?? '';
      final mobile = json['mobile']?.toString() ?? '';
      final company = json['companyName']?.toString() ?? '';
      description =
          'Email: $email, Mobile: $mobile${company.isNotEmpty ? ', Company: $company' : ''}';
    } else {
      description =
          (json['description'] ??
                  json['body'] ??
                  json['templateHeader'] ??
                  json['messageBody'] ??
                  json['message_body'] ??
                  '')
              .toString();
    }

    // Template-specific fields
    final String? templateId =
        (json['templateId'] ?? json['template_id'])?.toString();
    final String? templateType =
        (json['templateType'] ?? json['template_type'] ?? json['type'])
            ?.toString();
    final String? templateName =
        (json['templateName'] ?? json['template_name'])?.toString();
    final String? templateHeader =
        (json['templateHeader'] ?? json['template_header'])?.toString();
    final String? bodyField =
        (json['body'] ?? json['messageBody'] ?? json['message_body'])
            ?.toString();

    // Extract createdBy ID and name
    String? createdBy;
    String? createdByName;
    final createdByData = json['createdBy'] ?? json['created_by'];
    if (createdByData is Map) {
      createdBy = createdByData['_id']?.toString();
      final firstName = createdByData['firstName']?.toString() ?? '';
      final lastName = createdByData['lastName']?.toString() ?? '';
      createdByName = '$firstName $lastName'.trim();
      if (createdByName.isEmpty) createdByName = null;
    } else if (createdByData != null) {
      createdBy = createdByData.toString();
    }

    final bool? isActive =
        json['isActive'] is bool
            ? json['isActive']
            : (json['isActive'] == null
                ? null
                : json['isActive'].toString().toLowerCase() == 'true');
    final bool? isApproved =
        json['isApproved'] is bool
            ? json['isApproved']
            : (json['isApproved'] == null
                ? null
                : json['isApproved'].toString().toLowerCase() == 'true');
    final String? status = (json['status'])?.toString();
    DateTime? updatedAt;
    final updatedVal =
        json['updatedat'] ??
        json['updatedAt'] ??
        json['updated'] ??
        json['updated_at'];
    if (updatedVal is String) {
      try {
        updatedAt = DateTime.parse(updatedVal);
      } catch (_) {
        updatedAt = null;
      }
    } else if (updatedVal is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedVal);
    }
    final String? updatedBy =
        (json['updatedBy'] ?? json['updated_by'])?.toString();
    // Notification-specific fields
    final String? notificationId =
        (json['notificationId'] ?? json['notification_id'])?.toString();
    final String? notificationTempId =
        (json['notificationTempId'] ??
                json['notification_temp_id'] ??
                json['notification_tempid'])
            ?.toString();
    final String? messageHeader =
        (json['messageHeader'] ?? json['message_header'])?.toString();
    final String? messageBody =
        (json['messageBody'] ?? json['message_body'])?.toString();
    final String? link = (json['link'])?.toString();
    DateTime? scheduledDate;
    final schDateVal = json['scheduledDate'] ?? json['scheduled_date'];
    if (schDateVal is String) {
      try {
        scheduledDate = DateTime.parse(schDateVal);
      } catch (_) {
        scheduledDate = null;
      }
    } else if (schDateVal is int) {
      scheduledDate = DateTime.fromMillisecondsSinceEpoch(schDateVal);
    }
    DateTime? scheduledTime;
    final schTimeVal = json['scheduledTime'] ?? json['scheduled_time'];
    if (schTimeVal is String) {
      try {
        scheduledTime = DateTime.parse(schTimeVal);
      } catch (_) {
        scheduledTime = null;
      }
    } else if (schTimeVal is int) {
      scheduledTime = DateTime.fromMillisecondsSinceEpoch(schTimeVal);
    }
    List<String>? targetUsers;
    if (json['targetUsers'] is List) {
      targetUsers =
          (json['targetUsers'] as List).map((e) => e.toString()).toList();
    }
    final String? lastUpdatedBy =
        (json['lastUpdatedBy'] ??
                json['last_updated_by'] ??
                json['lastUpdated'])
            ?.toString();

    // Banner-specific fields
    final String? bannerId =
        (json['bannerId'] ?? json['banner_id'])?.toString();
    final String? bannerName = (json['name'])?.toString();
    final String? bannerTitle = (json['title'])?.toString();
    final String? bannerImageUrl =
        (json['bannerImageUrl'] ?? json['banner_image_url'])?.toString();
    final String? bannerUrl =
        (json['bannerUrl'] ?? json['banner_url'])?.toString();

    // Profile edit request specific fields
    final String? profileId = (json['_id'])?.toString();
    final String? mobile = (json['mobile'])?.toString();
    final String? firstName = (json['firstName'])?.toString();
    final String? lastName = (json['lastName'])?.toString();
    final String? email = (json['email'])?.toString();
    final String? alternateEmail = (json['alternateEmail'])?.toString();
    final String? alternateMobile = (json['alternateMobile'])?.toString();
    final String? companyName = (json['companyName'])?.toString();
    final String? department = (json['department'])?.toString();
    final String? designation = (json['designation'])?.toString();
    final String? profileImageUrl = (json['profileImageUrl'])?.toString();
    final String? address = (json['address'])?.toString();
    final String? country = (json['country'])?.toString();
    final String? region = (json['region'])?.toString();
    final String? landlineNumber = (json['landlineNumber'])?.toString();
    final String? extentionNumber = (json['extentionNumber'])?.toString();
    final bool? activeRmsUser =
        json['Active_RMS_User'] is bool
            ? json['Active_RMS_User']
            : (json['Active_RMS_User'] == null
                ? null
                : json['Active_RMS_User'].toString().toLowerCase() == 'true');

    return PendingApprovalItem(
      id: id,
      mongoId: json['_id']?.toString(),
      type: type,
      title: title,
      description: description,
      createdAt: createdAt,
      templateId: templateId,
      templateType: templateType,
      templateName: templateName,
      templateHeader: templateHeader,
      body: bodyField,
      createdBy: createdBy,
      createdByName: createdByName,
      isActive: isActive,
      isApproved: isApproved,
      status: status,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      notificationId: notificationId,
      notificationTempId: notificationTempId,
      messageHeader: messageHeader,
      messageBody: messageBody,
      link: link,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      targetUsers: targetUsers,
      lastUpdatedBy: lastUpdatedBy,
      bannerId: bannerId,
      bannerName: bannerName,
      bannerTitle: bannerTitle,
      bannerImageUrl: bannerImageUrl,
      bannerUrl: bannerUrl,
      profileId: profileId,
      mobile: mobile,
      firstName: firstName,
      lastName: lastName,
      email: email,
      alternateEmail: alternateEmail,
      alternateMobile: alternateMobile,
      companyName: companyName,
      department: department,
      designation: designation,
      profileImageUrl: profileImageUrl,
      address: address,
      country: country,
      region: region,
      landlineNumber: landlineNumber,
      extentionNumber: extentionNumber,
      activeRmsUser: activeRmsUser,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': describeEnum(type),
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'templateId': templateId,
    'templateType': templateType,
    'templateName': templateName,
    'templateHeader': templateHeader,
    'body': body,
    'createdBy': createdBy,
    'isActive': isActive,
    'isApproved': isApproved,
    'status': status,
    'updatedAt': updatedAt?.toIso8601String(),
    'updatedBy': updatedBy,
    'notificationId': notificationId,
    'notificationTempId': notificationTempId,
    'messageHeader': messageHeader,
    'messageBody': messageBody,
    'link': link,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'scheduledTime': scheduledTime?.toIso8601String(),
    'targetUsers': targetUsers,
    'lastUpdatedBy': lastUpdatedBy,
    'bannerId': bannerId,
    'bannerName': bannerName,
    'bannerTitle': bannerTitle,
    'bannerImageUrl': bannerImageUrl,
    'bannerUrl': bannerUrl,
    'profileId': profileId,
    'mobile': mobile,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'alternateEmail': alternateEmail,
    'alternateMobile': alternateMobile,
    'companyName': companyName,
    'department': department,
    'designation': designation,
    'profileImageUrl': profileImageUrl,
    'address': address,
    'country': country,
    'region': region,
    'landlineNumber': landlineNumber,
    'extentionNumber': extentionNumber,
    'activeRmsUser': activeRmsUser,
  };
}
