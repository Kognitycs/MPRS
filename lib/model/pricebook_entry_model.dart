class PricebookEntryModel {
  final String id;

  final String? product2Id;

  final String productName;

  final String originName;

  final String originCode;

  /// Origin port name from `Product2.Origin_Port__r` (when route starts at a port).
  final String originPortName;

  /// Origin ICD name from `Product2.ICDS__r` (when route starts at an ICD).
  final String originIcdName;

  final String destinationName;

  final String destinationCode;

  /// Destination port name from `Product2.Destination_Port__r`.
  final String destinationPortName;

  /// Destination ICD name from `Product2.Destination_ICD__r`.
  final String destinationIcdName;

  final String containerSize;

  final String containerType;

  final String mloCode;

  final int? estimatedTransitTime;

  final String? routing;

  /// Transshipment / via port from API (`Via_Port__c`). Empty = direct route.
  final String? viaPort;

  final double unitPrice;

  final double? suggestedMarginC;

  /// null = not set on the pricebook entry (use default margin when other margins blank).
  final bool? overrideAccountMarginC;

  final String? mprsCurrencyC;

  final String? pricebook2Id;

  final Product2Model? product2;

  PricebookEntryModel({
    required this.id,

    this.product2Id,

    required this.productName,

    required this.originName,

    required this.originCode,

    this.originPortName = '',

    this.originIcdName = '',

    required this.destinationName,

    required this.destinationCode,

    this.destinationPortName = '',

    this.destinationIcdName = '',

    required this.containerSize,

    required this.containerType,

    required this.mloCode,

    this.estimatedTransitTime,

    this.routing,

    this.viaPort,

    required this.unitPrice,

    this.suggestedMarginC,

    this.overrideAccountMarginC,

    this.mprsCurrencyC,

    this.pricebook2Id,

    this.product2,
  });

  /// e.g. "18 Days" — null when API has no transit time.
  String? get transitTimeDisplay {
    if (estimatedTransitTime != null && estimatedTransitTime! > 0) {
      return '$estimatedTransitTime Days';
    }
    return null;
  }

  /// Normalized routing label for UI (Direct vs Indirect / Transshipment).
  String get routingDisplay {
    final raw = routing?.trim();
    if (raw != null && raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == 'direct' || lower == 'direct route') {
        return 'Direct';
      }
      if (lower == 'false' ||
          lower.contains('indirect') ||
          lower.contains('transship') ||
          lower.contains('trans-ship')) {
        return _indirectRoutingLabel();
      }
      return raw;
    }

    final via = viaPort?.trim();
    if (via != null && via.isNotEmpty) {
      return _indirectRoutingLabel();
    }
    return 'Direct';
  }

  String _indirectRoutingLabel() {
    final via = viaPort?.trim();
    if (via != null && via.isNotEmpty) {
      return 'Indirect / Transshipment (via $via)';
    }
    return 'Indirect / Transshipment';
  }

  factory PricebookEntryModel.fromJson(Map<String, dynamic> json) {
    final product = json['Product2'] as Map<String, dynamic>?;

    final originPort = product?['Origin_Port__r'] as Map<String, dynamic>?;

    final originIcd = product?['ICDS__r'] as Map<String, dynamic>?;

    final destPort = product?['Destination_Port__r'] as Map<String, dynamic>?;

    final destIcd = product?['Destination_ICD__r'] as Map<String, dynamic>?;

    final pricebook2 = json['Pricebook2'] as Map<String, dynamic>?;

    final mlo = pricebook2?['MLO_Name__r'] as Map<String, dynamic>?;

    final originPortName = originPort?['Name']?.toString().trim() ?? '';
    final originIcdName = originIcd?['Name']?.toString().trim() ?? '';
    final destinationPortName = destPort?['Name']?.toString().trim() ?? '';
    final destinationIcdName = destIcd?['Name']?.toString().trim() ?? '';

    return PricebookEntryModel(
      id: json['Id'] ?? "",

      product2Id: json['Product2Id'] ?? "",

      productName: json['Name'] ?? product?['Name']?.toString() ?? '',

      originPortName: originPortName,

      originIcdName: originIcdName,

      originName:
          originPortName.isNotEmpty ? originPortName : originIcdName,

      originCode: originPort?['Port_Code__c']?.toString() ?? "",

      destinationPortName: destinationPortName,

      destinationIcdName: destinationIcdName,

      destinationName:
          destinationPortName.isNotEmpty
              ? destinationPortName
              : destinationIcdName,

      destinationCode: destPort?['Port_Code__c']?.toString() ?? "",

      containerSize:
          json['Container_Size__c']?.toString() ??
          product?['Size__c']?.toString() ??
          "",

      containerType:
          json['Container_Type__c']?.toString() ??
          product?['Type__c']?.toString() ??
          "",

      mloCode:
          pricebook2?['MLO_Code__c']?.toString() ??
          mlo?['MLO_Code__c']?.toString() ??
          "",

      estimatedTransitTime: _readTransitTime(json, product, pricebook2),

      routing: _readRouting(json, product, pricebook2),

      viaPort: _nullableString(json['Via_Port__c']),

      unitPrice: (json['UnitPrice'] ?? 0).toDouble(),

      suggestedMarginC: _readOptionalDouble(json['Suggested_Margin__c']),

      overrideAccountMarginC:
          json['Override_Account_Margin__c'] == null
              ? null
              : json['Override_Account_Margin__c'] == true,

      mprsCurrencyC: json['MPRS_Currency__c'] ?? "USD",

      pricebook2Id: json['Pricebook2Id'] as String?,

      product2:
          json['Product2'] != null
              ? Product2Model.fromJson(json['Product2'])
              : null,
    );
  }

  static int? _readTransitTime(
    Map<String, dynamic> json,
    Map<String, dynamic>? product,
    Map<String, dynamic>? pricebook2,
  ) {
    const keys = [
      'Estimated_Transit_Time__c',
      'Transit_Time__c',
      'Transit_Days__c',
      'Estimated_Transit_Days__c',
      'Transit_Time_Days__c',
      'Transit_Time_In_Days__c',
      'TT__c',
      'estimatedTransitTime',
      'transitTime',
    ];

    final mlo = pricebook2?['MLO_Name__r'] as Map<String, dynamic>?;

    for (final source in [json, product, pricebook2, mlo]) {
      if (source == null) continue;
      for (final key in keys) {
        final parsed = _parseTransitTime(source[key]);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int? _parseTransitTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final n = value.toInt();
      return n > 0 ? n : null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final direct = int.tryParse(text);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match != null) {
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static double? _readOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _readRouting(
    Map<String, dynamic> json,
    Map<String, dynamic>? product,
    Map<String, dynamic>? pricebook2,
  ) {
    final viaPort = _nullableString(json['Via_Port__c']);
    if (viaPort != null) return 'Indirect / Transshipment';

    const keys = [
      'Routing__c',
      'Routing_Type__c',
      'Route_Type__c',
      'Direct_Indirect_Routing__c',
      'Direct_or_Indirect__c',
      'MLO_Routing__c',
      'Shipment_Routing__c',
    ];

    final mlo = pricebook2?['MLO_Name__r'] as Map<String, dynamic>?;

    for (final source in [json, product, pricebook2, mlo]) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }

    for (final source in [json, product, pricebook2, mlo]) {
      if (source == null) continue;
      final directFlag = source['Is_Direct__c'] ?? source['Direct_Route__c'];
      if (directFlag is bool) {
        return directFlag ? 'Direct' : 'Indirect / Transshipment';
      }
      final flagText = directFlag?.toString().trim().toLowerCase();
      if (flagText == 'true') return 'Direct';
      if (flagText == 'false') return 'Indirect / Transshipment';
    }

    return null;
  }

  /// True when [selected] matches this entry's origin port or origin ICD name/code.
  bool matchesOriginSelection(String? selected) {
    if (selected == null || selected.trim().isEmpty) return true;
    final value = selected.trim();
    for (final candidate in [
      originName,
      originCode,
      originPortName,
      originIcdName,
    ]) {
      if (candidate.trim().isNotEmpty && candidate.trim() == value) return true;
    }
    return false;
  }

  /// True when [selected] matches this entry's destination port or ICD name/code.
  bool matchesDestinationSelection(String? selected) {
    if (selected == null || selected.trim().isEmpty) return true;
    final value = selected.trim();
    for (final candidate in [
      destinationName,
      destinationCode,
      destinationPortName,
      destinationIcdName,
    ]) {
      if (candidate.trim().isNotEmpty && candidate.trim() == value) return true;
    }
    return false;
  }

  bool get isMarginProduct {
    final name = productName.toLowerCase();
    final family = (product2?.family ?? "").toLowerCase();

    return name.contains("ocean freight") ||
        name.contains("thc") ||
        name.contains("terminal handling") ||
        family.contains("ocean freight") ||
        family.contains("thc") ||
        family.contains("terminal handling");
  }
}

class Product2Model {
  final String? family;

  Product2Model({this.family});

  factory Product2Model.fromJson(Map<String, dynamic> json) {
    return Product2Model(family: json['Family']);
  }
}
