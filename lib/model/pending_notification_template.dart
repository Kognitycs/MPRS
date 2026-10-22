class PendingTemplateListResponse {
  final int? currentPage;
  final int? totalPages;
  final int? totalRecords;
  final int? recordsInPage;
  final List<TemplateModel>? data;

  PendingTemplateListResponse({
    this.currentPage,
    this.totalPages,
    this.totalRecords,
    this.recordsInPage,
    this.data,
  });

  factory PendingTemplateListResponse.fromJson(Map<String, dynamic> json) {
    return PendingTemplateListResponse(
      currentPage: json["currentPage"],
      totalPages: json["totalPages"],
      totalRecords: json["totalRecords"],
      recordsInPage: json["recordsInPage"],
      data: (json["data"] as List<dynamic>?)
          ?.map((item) => TemplateModel.fromJson(item))
          .toList(),
    );
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
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json["_id"],
      templateId: json["templateId"],
      templateType: json["templateType"],
      templateName: json["templateName"],
      templateHeader: json["templateHeader"],
      body: json["body"],
      isApproved: json['isApproved'] ?? false,
      status: json['status'] ?? '',
      createdBy: json["createdBy"],
      isActive: json["isActive"],
      createdAt: json["createdat"],
      updatedAt: json["updatedat"],
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
}
