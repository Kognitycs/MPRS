class PortModel {
  final String? portId;
  final String? name;
  final String? portCode;
  final String? country;
  final String? sectorId;
  final String? sectorName;
  final bool? isActive;

  PortModel({
    this.portId,
    this.name,
    this.portCode,
    this.country,
    this.sectorId,
    this.sectorName,
    this.isActive,
  });

  factory PortModel.fromJson(Map<String, dynamic> json) {
    // 🔥 Extract ID from URL if portId not available
    String? extractedId;

    if (json['attributes'] != null && json['attributes']['url'] != null) {
      String url = json['attributes']['url'];
      extractedId = url.split('/').last; // ✅ ID extraction
    }

    return PortModel(
      portId: json['portId'] ?? extractedId, // ✅ FIX HERE
      name: json['name'],
      portCode: json['portCode'],
      country: json['country'],
      sectorId: json['sectorId'],
      sectorName: json['sectorName'],
      isActive: json['IsActive'],
    );
  }
}class PortListResponse {
  final int? count;
  final List<PortModel>? data;

  PortListResponse({this.count, this.data});

  factory PortListResponse.fromJson(Map<String, dynamic> json) {
    return PortListResponse(
      count: json['count'],
      data:
          json['data'] != null
              ? (json['data'] as List)
                  .map((e) => PortModel.fromJson(e))
                  .toList()
              : null,
    );
  }
}
