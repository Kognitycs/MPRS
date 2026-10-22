import 'dart:convert';

class TemplateListResponse {
  final int? currentPage;
  final int? totalPages;
  final int? totalRecords;
  final int? recordsInPage;
  final List<TemplateModel>? data;

  TemplateListResponse({
    this.currentPage,
    this.totalPages,
    this.totalRecords,
    this.recordsInPage,
    this.data,
  });

  factory TemplateListResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> rawList = const [];

    if (json['data'] is List) {
      rawList = json['data'] as List;
    } else if (json['data'] is Map) {
      final inner = Map<String, dynamic>.from(json['data'] as Map);
      if (inner['data'] is List) {
        rawList = inner['data'] as List;
      } else if (inner['items'] is List) {
        rawList = inner['items'] as List;
      } else if (inner['records'] is List) {
        rawList = inner['records'] as List;
      } else if (inner['templates'] is List) {
        rawList = inner['templates'] as List;
      } else if (inner['notificationTemplates'] is List) {
        rawList = inner['notificationTemplates'] as List;
      }
    } else if (json['items'] is List) {
      rawList = json['items'] as List;
    } else if (json['records'] is List) {
      rawList = json['records'] as List;
    } else if (json['templates'] is List) {
      rawList = json['templates'] as List;
    } else if (json['notificationTemplates'] is List) {
      rawList = json['notificationTemplates'] as List;
    }

    return TemplateListResponse(
      currentPage: json['currentPage'] ?? json['page'],
      totalPages: json['totalPages'],
      totalRecords: json['totalRecords'],
      recordsInPage: json['recordsInPage'],
      data:
          rawList
              .whereType<Map>()
              .map((item) => TemplateModel.fromJson(Map<String, dynamic>.from(item)))
              .toList(),
    );
  }

  /// Parses list/paginated/template API bodies into a uniform response.
  static TemplateListResponse parse(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return TemplateListResponse(data: const []);
      }
    }

    if (decoded is List) {
      return TemplateListResponse(
        currentPage: 1,
        totalPages: 1,
        data:
            decoded
                .whereType<Map>()
                .map(
                  (item) =>
                      TemplateModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(),
      );
    }

    if (decoded is! Map) {
      return TemplateListResponse(data: const []);
    }

    final map = Map<String, dynamic>.from(decoded);
    var response = TemplateListResponse.fromJson(map);
    if (response.data?.isNotEmpty == true) return response;

    if (map['data'] is Map) {
      response = TemplateListResponse.fromJson(
        Map<String, dynamic>.from(map['data'] as Map),
      );
      if (response.data?.isNotEmpty == true) return response;
    }

    return response;
  }

  Map<String, dynamic> toJson() {
    return {
      "currentPage": currentPage,
      "totalPages": totalPages,
      "totalRecords": totalRecords,
      "recordsInPage": recordsInPage,
      "data": data?.map((e) => e.toJson()).toList(),
    };
  }
}

class TemplateModel {
  final String? id;
  final String? templateId;
  final String? templateType;
  final String? templateName;
  final String? templateHeader;
  final String? body;
  final bool? isApproved;
  final String? status;
  final String? createdBy;
  final String? createdByName;
  final bool? isActive;
  final String? createdAt;
  final String? updatedAt;

  TemplateModel({
    this.id,
    this.templateId,
    this.templateType,
    this.templateName,
    this.templateHeader,
    this.body,
    this.isApproved,
    this.status,
    this.createdBy,
    this.createdByName,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      templateId:
          json['templateId']?.toString() ??
          json['_id']?.toString() ??
          json['id']?.toString(),
      templateType: json['templateType']?.toString(),
      templateName: json['templateName']?.toString(),
      templateHeader: json['templateHeader']?.toString(),
      body: json['body']?.toString(),
      isApproved: _parseBool(json['isApproved'] ?? json['IsApproved']),
      status: json['status']?.toString() ?? '',
      createdBy:
          json["createdBy"] is Map
              ? json["createdBy"]["_id"]
              : json["createdBy"],
      createdByName:
          json["createdBy"] is Map
              ? "${json["createdBy"]["firstName"] ?? ''} ${json["createdBy"]["lastName"] ?? ''}"
                  .trim()
              : null,
      isActive: _parseBool(json['isActive'] ?? json['IsActive']),
      createdAt:
          json['createdat'] ??
          json['createdAt'] ??
          json['CreatedAt']?.toString(),
      updatedAt:
          json['updatedat'] ??
          json['updatedAt'] ??
          json['UpdatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "templateId": templateId,
      "templateType": templateType,
      "templateName": templateName,
      "templateHeader": templateHeader,
      "body": body,
      "createdBy": createdBy,
      "isActive": isActive,
      "createdat": createdAt,
      "updatedat": updatedAt,
    };
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }
}
