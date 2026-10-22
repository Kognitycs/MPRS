class BannerItem {
  final String id;
  final String bannerId;
  final String name;
  final String title;
  final String description;
  final String bannerUrl;
  final String bannerImageUrl;
  final bool isActive;
  final String status;
  final bool isApproved;
  final String lastUpdatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? linkType; // 'External' or 'Internal'
  final String? linkRef; // URL for External, page name for Internal

  BannerItem({
    required this.id,
    required this.bannerId,
    required this.name,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.bannerImageUrl,
    required this.isActive,
    required this.status,
    required this.isApproved,
    required this.lastUpdatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.linkType,
    this.linkRef,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['_id']?.toString() ?? '',
      bannerId: json['bannerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      bannerUrl: json['bannerUrl']?.toString() ?? '',
      bannerImageUrl: json['bannerImageUrl']?.toString() ?? '',
      isActive: json['isActive'] == true,
      status: json['status']?.toString() ?? '',
      isApproved: json['isApproved'] == true,
      lastUpdatedBy: json['lastUpdatedBy']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      linkType: json['linkType']?.toString(),
      linkRef: json['linkRef']?.toString(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  BannerItem copyWith({
    String? id,
    String? bannerId,
    String? name,
    String? title,
    String? description,
    String? bannerUrl,
    String? bannerImageUrl,
    bool? isActive,
    String? status,
    bool? isApproved,
    String? lastUpdatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? linkType,
    String? linkRef,
  }) {
    return BannerItem(
      id: id ?? this.id,
      bannerId: bannerId ?? this.bannerId,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkType: linkType ?? this.linkType,
      linkRef: linkRef ?? this.linkRef,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'bannerId': bannerId,
      'name': name,
      'title': title,
      'description': description,
      'bannerUrl': bannerUrl,
      'bannerImageUrl': bannerImageUrl,
      'isActive': isActive,
      'status': status,
      'isApproved': isApproved,
      'lastUpdatedBy': lastUpdatedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'linkType': linkType,
      'linkRef': linkRef,
    };
  }
}
