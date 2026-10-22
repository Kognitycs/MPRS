class SavedQuotationsModel {
  Attributes? attributes;
  String? id;
  String? name;
  PortMaster? originPortR;
  String? createdDateC;
  PortMaster? destinationPortR;
  String? currencyIsoCode;
  num? totalPrice;
  num? goodsValue;
  String? loadType;
  String? containerType;
  String? containerSize;
  String? modeOfShipment;
  num? netWeight;
  num? grossWeight;
  String? commodity;
  String? expirationDate;
  String? status;
  String? opportunityName;
  String? accountName;
  String? accountId;
  /// True when linked Opportunity was created from the RMS app (`opp_from_rms_app`).
  bool? opportunityFromRms;

  SavedQuotationsModel({
    this.attributes,
    this.id,
    this.name,
    this.originPortR,
    this.createdDateC,
    this.destinationPortR,
    this.currencyIsoCode,
    this.totalPrice,
    this.goodsValue,
    this.loadType,
    this.containerType,
    this.containerSize,
    this.modeOfShipment,
    this.netWeight,
    this.grossWeight,
    this.commodity,
    this.expirationDate,
    this.status,
    this.opportunityName,
    this.accountName,
    this.accountId,
    this.opportunityFromRms,
  });

  /// Quotes whose opportunity originated in RMS (admin Available Bookings filter).
  bool get isOpportunityFromRms => opportunityFromRms == true;

  /// Dev/QA quotes (e.g. QT-TEST01) — excluded from Available Bookings.
  bool get isTestQuoteData =>
      isTestQuoteLabel(name, opportunityName: opportunityName);

  /// Normalize Salesforce / app quote status for list filters.
  static String normalizeQuoteListStatus(String? raw) {
    final status = raw?.trim().toLowerCase() ?? '';
    if (status.isEmpty) return '';
    if (status == 'approved' || status.contains('accept')) return 'accepted';
    if (status.contains('present') || status.contains('pending')) {
      return 'presented';
    }
    if (status.contains('draft')) return 'draft';
    if (status.contains('denied') || status.contains('reject')) {
      return 'denied';
    }
    const known = {'draft', 'accepted', 'presented', 'denied'};
    if (known.contains(status)) return status;
    return status;
  }

  static bool isInProgressListStatus(String? raw) {
    final status = normalizeQuoteListStatus(raw);
    return status == 'draft' ||
        status == 'accepted' ||
        status == 'presented';
  }

  /// Book → Quotations tabs (draft, pending, accepted; not booked).
  static bool isQuotationsTabStatus(String? raw) {
    final status = normalizeQuoteListStatus(raw);
    return status == 'draft' || status == 'accepted' || status == 'presented';
  }

  static bool isDraftStatus(String? raw) =>
      normalizeQuoteListStatus(raw) == 'draft';

  static bool isPendingStatus(String? raw) =>
      normalizeQuoteListStatus(raw) == 'presented';

  static bool isAcceptedStatus(String? raw) =>
      normalizeQuoteListStatus(raw) == 'accepted';

  /// True for QT-TEST* quote names and obvious test MSL labels.
  static bool isTestQuoteLabel(
    String? quoteName, {
    String? opportunityName,
  }) {
    final name = (quoteName ?? '').trim().toLowerCase();
    if (name.isNotEmpty) {
      if (name == 'test quote' || name == 'test') return true;
      if (name.contains('test quote')) return true;
      if (name.contains('qt-test')) return true;
      if (RegExp(r'^qt[\s_.-]*test').hasMatch(name)) return true;
    }
    final opp = (opportunityName ?? '').trim().toLowerCase();
    if (opp.isNotEmpty) {
      if (opp.contains('qt-test')) return true;
      if (RegExp(r'^msl[\s_.-]*test').hasMatch(opp)) return true;
    }
    return false;
  }

  /// Default SF opportunity quote shell (e.g. MSL2026050216 - Q1), not an app QT quote.
  static bool isOpportunityShellQuoteName(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return false;
    if (RegExp(r'^qt-', caseSensitive: false).hasMatch(n)) return false;
    return RegExp(
      r'^msl\d+(\s*-\s*q\d+)?$',
      caseSensitive: false,
    ).hasMatch(n);
  }

  /// Empty opportunity shell rows — hide from Book → Quotations (All/Draft).
  bool get isEmptyOpportunityShellQuote =>
      isOpportunityShellQuoteName(name) && !hasResolvedPorts;

  /// Marks quote as created from an app opportunity (SF RMS list / merge).
  SavedQuotationsModel asAppOpportunityQuote() {
    if (opportunityFromRms == true) return this;
    return SavedQuotationsModel(
      attributes: attributes,
      id: id,
      name: name,
      originPortR: originPortR,
      createdDateC: createdDateC,
      destinationPortR: destinationPortR,
      currencyIsoCode: currencyIsoCode,
      totalPrice: totalPrice,
      goodsValue: goodsValue,
      loadType: loadType,
      containerType: containerType,
      containerSize: containerSize,
      modeOfShipment: modeOfShipment,
      netWeight: netWeight,
      grossWeight: grossWeight,
      commodity: commodity,
      expirationDate: expirationDate,
      status: status,
      opportunityName: opportunityName,
      accountName: accountName,
      accountId: accountId,
      opportunityFromRms: true,
    );
  }

  factory SavedQuotationsModel.fromJson(Map<String, dynamic> json) {
    final opportunity =
        json['Opportunity'] ?? json['Opportunity__r'] ?? json['opportunity'];
    String? opportunityName;
    if (opportunity is Map) {
      opportunityName = opportunity['Name']?.toString();
    }

    String? accountName;
    final account = json['Account'];
    if (account is Map) {
      accountName = account['Name']?.toString();
    } else {
      accountName = json['accountName']?.toString() ??
          json['companyName']?.toString();
    }

    final accountId = _readString(
      json['AccountId'] ??
          json['accountId'] ??
          json['account_id'] ??
          (account is Map ? account['Id'] : null),
    );

    return SavedQuotationsModel(
      attributes:
          json['attributes'] != null
              ? Attributes.fromJson(json['attributes'])
              : null,
      id:
          json['Id']?.toString() ??
          json['id']?.toString() ??
          json['quoteId']?.toString() ??
          json['QuoteId']?.toString(),
      name:
          json['Name']?.toString() ??
          json['name']?.toString() ??
          json['quoteName']?.toString(),
      originPortR: _parsePort(
        json['Origin_Port__r'] ?? json['Port_of_Loading__r'],
        json,
        'Origin',
      ),
      createdDateC:
          json['CreatedDate']?.toString() ??
          json['Created_Date__c']?.toString() ??
          json['createdDate']?.toString() ??
          json['createdAt']?.toString() ??
          json['created_at']?.toString() ??
          json['LastModifiedDate']?.toString() ??
          json['SystemModstamp']?.toString(),
      destinationPortR: _parsePort(
        json['Destination_Port__r'] ?? json['Port_of_Destination__r'],
        json,
        'Destination',
      ),
      currencyIsoCode:
          json['CurrencyIsoCode']?.toString() ?? json['currency']?.toString(),
      totalPrice: _readNum(
        json['TotalPrice'] ??
            json['GrandTotal'] ??
            json['grandTotal'] ??
            json['totalPrice'],
      ),
      goodsValue: _readNum(
        json['Goods_Value__c'] ?? json['goodsValue'] ?? json['GoodsValue'],
      ),
      loadType: _readString(
        json['Load_Type__c'] ??
            json['LoadType__c'] ??
            json['loadType'] ??
            json['Lead_Type__c'] ??
            json['leadType'] ??
            json['LeadType__c'],
      ),
      containerType: _readString(
        json['Container_Type__c'] ??
            json['containerType'] ??
            json['ContainerType__c'] ??
            (opportunity is Map
                ? opportunity['Container_Type__c'] ??
                    opportunity['containerType'] ??
                    opportunity['ContainerType__c']
                : null),
      ),
      containerSize: _readString(
        json['Container_Size__c'] ??
            json['containerSize'] ??
            json['ContainerSize__c'] ??
            (opportunity is Map
                ? opportunity['Container_Size__c'] ??
                    opportunity['containerSize'] ??
                    opportunity['ContainerSize__c']
                : null),
      ),
      modeOfShipment: _readString(
        json['Mode_of_Shipment__c'] ??
            json['Mode_Of_Shipment__c'] ??
            json['mode_of_shipment'] ??
            json['modeOfShipment'] ??
            (opportunity is Map
                ? opportunity['Mode_of_Shipment__c'] ??
                    opportunity['Mode_Of_Shipment__c'] ??
                    opportunity['mode_of_shipment'] ??
                    opportunity['modeOfShipment']
                : null),
      ),
      netWeight: _readNum(
        json['Net_Weight__c'] ??
            json['Net_Weight_KGS__c'] ??
            json['netWeight'] ??
            json['weightPerContainer'],
      ),
      grossWeight: _readNum(
        json['Gross_Weight__c'] ??
            json['Gross_Weight_KGS__c'] ??
            json['grossWeight'],
      ),
      commodity: _readString(
        json['Commodity__c'] ??
            json['commodity'] ??
            json['Commodity_Description__c'] ??
            json['additionalInfo'] ??
            json['additional_info'] ??
            json['Additional_Info__c'] ??
            json['Additional_Information__c'] ??
            json['Cargo_Description__c'] ??
            json['Goods_Description__c'],
      ),
      expirationDate:
          json['ExpirationDate']?.toString() ??
          json['Expiration_Date__c']?.toString(),
      status: json['Status']?.toString() ?? json['status']?.toString(),
      opportunityName: opportunityName ?? json['opportunityName']?.toString(),
      accountName: accountName,
      accountId: accountId,
      opportunityFromRms: _parseOpportunityFromRms(json, opportunity),
    );
  }

  static bool? _parseOpportunityFromRms(
    Map<String, dynamic> json,
    dynamic opportunity,
  ) {
    final candidates = <dynamic>[
      if (opportunity is Map) ...[
        opportunity['Opp_From_RMS_App__c'],
        opportunity['opp_from_rms_app'],
        opportunity['Opp_from_RMS_App__c'],
        opportunity['opportunityFromRms'],
        opportunity['rms'],
      ],
      json['Opp_From_RMS_App__c'],
      json['opp_from_rms_app'],
      json['Opp_from_RMS_App__c'],
      json['opportunityFromRms'],
      json['opportunity_rms'],
      json['opportunityRms'],
      json['isFromRmsApp'],
      json['fromRmsApp'],
      json['from_app'],
    ];

    for (final value in candidates) {
      final parsed = _parseBool(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  /// Maps to booking In Progress tab (quote rows).
  Map<String, dynamic> toInProgressBookingJson() {
    return {
      'Id': id,
      'Name': name,
      'QuoteId': id,
      'Status': status,
      if (createdDateC != null) 'CreatedDate': createdDateC,
      if (expirationDate != null) 'ExpirationDate': expirationDate,
      if (originPortR?.name != null)
        'Origin_Port__r': {'Name': originPortR!.name},
      if (destinationPortR?.name != null)
        'Destination_Port__r': {'Name': destinationPortR!.name},
      if (opportunityName != null) 'Opportunity': {'Name': opportunityName},
      if (accountName != null) 'Account': {'Name': accountName},
      if (loadType != null) 'Lead_Type__c': loadType,
      if (containerType != null) 'Container_Type__c': containerType,
      if (containerSize != null) 'Container_Size__c': containerSize,
      if (modeOfShipment != null) 'Mode_of_Shipment__c': modeOfShipment,
      'Tracking_Status__c':
          SavedQuotationsModel.normalizeQuoteListStatus(status).isNotEmpty
              ? SavedQuotationsModel.normalizeQuoteListStatus(status)
              : status,
    };
  }

  /// Maps to shipment list [Records] for admin Available Bookings tab.
  Map<String, dynamic> toShipmentRecordJson() {
    return {
      'Id': id,
      'Name': name,
      'Status': status,
      'ExpirationDate': expirationDate,
      if (createdDateC != null) 'CreatedDate': createdDateC,
      'GrandTotal': totalPrice,
      'Lead_Type__c': loadType,
      if (containerType != null) 'Container_Type__c': containerType,
      if (containerSize != null) 'Container_Size__c': containerSize,
      if (modeOfShipment != null) 'Mode_of_Shipment__c': modeOfShipment,
      'Net_Weight_KGS__c': netWeight,
      'Gross_Weight_KGS__c': grossWeight,
      'Goods_Value__c': goodsValue,
      if (originPortR?.name != null)
        'Origin_Port__r': {'Name': originPortR!.name},
      if (destinationPortR?.name != null)
        'Destination_Port__r': {'Name': destinationPortR!.name},
      if (opportunityName != null) 'Opportunity': {'Name': opportunityName},
      if (accountName != null) 'Account': {'Name': accountName},
    };
  }

  static bool _looksLikeSalesforceId(String? value) {
    if (value == null) return false;
    final text = value.trim();
    if (text.length < 15 || text.length > 18) return false;
    return RegExp(r'^[a-zA-Z0-9]{15,18}$').hasMatch(text);
  }

  static PortMaster? _parsePort(
    dynamic relation,
    Map<String, dynamic> json,
    String prefix,
  ) {
    if (relation is Map) {
      return PortMaster.fromJson(Map<String, dynamic>.from(relation));
    }
    return _portFromFlat(json, prefix);
  }

  static PortMaster? _portFromFlat(Map<String, dynamic> json, String prefix) {
    final isOrigin = prefix == 'Origin';
    final name =
        json['${prefix}_Port__r'] is Map
            ? (json['${prefix}_Port__r'] as Map)['Name']
            : json['Port_of_${isOrigin ? 'Loading' : 'Destination'}__r'] is Map
            ? (json['Port_of_${isOrigin ? 'Loading' : 'Destination'}__r']
                as Map)['Name']
            : json['${prefix}_Port__c'] ??
                json['Port_of_${isOrigin ? 'Loading' : 'Destination'}__c'] ??
                json[isOrigin ? 'portOfLoading' : 'portOfDischarge'] ??
                json[isOrigin ? 'portOfLoadingName' : 'portOfDischargeName'] ??
                json['${prefix}Port'];
    if (name == null || name.toString().isEmpty) return null;
    final text = name.toString().trim();
    if (_looksLikeSalesforceId(text)) return null;
    return PortMaster(name: text);
  }

  static num? _readNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString().replaceAll(',', ''));
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Origin port for list cards (falls back when API returns only an id).
  String get originPortLabel {
    final name = originPortR?.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'N/A';
  }

  /// Destination port for list cards.
  String get destinationPortLabel {
    final name = destinationPortR?.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'N/A';
  }

  /// Grand total with currency for list cards (e.g. "USD 115000").
  String get formattedPrice {
    if (totalPrice == null) return '—';
    final currency = (currencyIsoCode ?? 'USD').toUpperCase();
    final amount = totalPrice!.round().toString();
    return '$currency $amount';
  }

  DateTime? get _sortDate {
    var text = createdDateC?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    text = text.replaceFirst(' ', 'T');
    text = text.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (match) => '${match[1]}:${match[2]}',
    );
    return DateTime.tryParse(text)?.toLocal();
  }

  bool get hasResolvedPorts {
    final origin = originPortR?.name?.trim();
    final destination = destinationPortR?.name?.trim();
    return origin != null &&
        origin.isNotEmpty &&
        destination != null &&
        destination.isNotEmpty;
  }

  /// Valid quote id + real port names (excludes N/A placeholder rows).
  bool get shouldShowInRecentList {
    final quoteId = id?.trim();
    if (quoteId == null || quoteId.isEmpty) return false;
    return hasResolvedPorts;
  }

  /// Book / Shipments quotation lists — real route data required.
  bool get shouldShowInQuotationsList {
    if (isTestQuoteData) return false;
    if (isEmptyOpportunityShellQuote) return false;
    final quoteId = id?.trim();
    if (quoteId == null || quoteId.isEmpty) return false;
    return hasResolvedPorts;
  }

  /// Real user quote suitable for Shipments → In Progress (excludes test/mock rows).
  bool get isRealInProgressQuote {
    if (isTestQuoteData) return false;
    if (isEmptyOpportunityShellQuote) return false;
    if (!shouldShowInQuotationsList) return false;
    final label = (name ?? '').trim().toLowerCase();
    if (label == 'quote' || label == 'q-0000') return false;
    return true;
  }

  /// All user quotes, newest first, for Recent Quotations (deduped by id).
  static List<SavedQuotationsModel> forRecentList(
    List<SavedQuotationsModel> list,
  ) {
    final byId = <String, SavedQuotationsModel>{};
    for (final quote in list) {
      if (!quote.shouldShowInRecentList) continue;
      final id = quote.id!.trim();
      byId[id] = SavedQuotationsModel.merge([byId[id], quote]) ?? quote;
    }
    return sortNewestFirst(byId.values.toList());
  }

  /// Latest quotes first (created time descending).
  static List<SavedQuotationsModel> sortNewestFirst(
    List<SavedQuotationsModel> list,
  ) {
    final sorted = List<SavedQuotationsModel>.from(list);
    sorted.sort((a, b) {
      final da = a._sortDate;
      final db = b._sortDate;
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return (b.id ?? '').compareTo(a.id ?? '');
    });
    return sorted;
  }

  bool get hasDisplayData {
    return (id != null && id!.isNotEmpty) ||
        (name != null && name!.isNotEmpty) ||
        (originPortR?.name != null && originPortR!.name!.isNotEmpty) ||
        (destinationPortR?.name != null &&
            destinationPortR!.name!.isNotEmpty) ||
        (loadType != null && loadType!.isNotEmpty) ||
        (containerType != null && containerType!.isNotEmpty) ||
        (containerSize != null && containerSize!.isNotEmpty) ||
        (modeOfShipment != null && modeOfShipment!.isNotEmpty) ||
        netWeight != null ||
        grossWeight != null ||
        goodsValue != null ||
        totalPrice != null ||
        (expirationDate != null && expirationDate!.isNotEmpty);
  }

  /// Merge multiple partial quote payloads (first non-null field wins).
  static SavedQuotationsModel? merge(List<SavedQuotationsModel?> sources) {
    SavedQuotationsModel? result;
    for (final source in sources) {
      if (source == null) continue;
      if (!source.hasDisplayData && !source._hasWeightData) continue;
      if (result == null) {
        result = source;
        continue;
      }
      result = SavedQuotationsModel(
        attributes: result.attributes ?? source.attributes,
        id: result.id ?? source.id,
        name: result.name ?? source.name,
        originPortR: result.originPortR ?? source.originPortR,
        createdDateC: result.createdDateC ?? source.createdDateC,
        destinationPortR: result.destinationPortR ?? source.destinationPortR,
        currencyIsoCode: result.currencyIsoCode ?? source.currencyIsoCode,
        totalPrice: result.totalPrice ?? source.totalPrice,
        goodsValue: result.goodsValue ?? source.goodsValue,
        loadType: result.loadType ?? source.loadType,
        containerType: result.containerType ?? source.containerType,
        containerSize: result.containerSize ?? source.containerSize,
        modeOfShipment: result.modeOfShipment ?? source.modeOfShipment,
        netWeight: result.netWeight ?? source.netWeight,
        grossWeight: result.grossWeight ?? source.grossWeight,
        commodity: result.commodity ?? source.commodity,
        expirationDate: result.expirationDate ?? source.expirationDate,
        status: result.status ?? source.status,
        opportunityName: result.opportunityName ?? source.opportunityName,
        accountName: result.accountName ?? source.accountName,
        accountId: result.accountId ?? source.accountId,
        opportunityFromRms:
            result.opportunityFromRms == true ||
                source.opportunityFromRms == true
            ? true
            : (result.opportunityFromRms ?? source.opportunityFromRms),
      );
    }
    return (result?.hasDisplayData == true || result?._hasWeightData == true)
        ? result
        : null;
  }

  bool get _hasWeightData => netWeight != null || grossWeight != null;

  /// Build from detailed booking / order payload when Quote object is not returned.
  factory SavedQuotationsModel.fromBookingMap(
    Map<String, dynamic> json, {
    String? quoteId,
  }) {
    final originName =
        json['Origin_Port__r'] is Map
            ? json['Origin_Port__r']['Name']?.toString()
            : json['Port_of_Loading__c']?.toString();
    final destName =
        json['Destination_Port__r'] is Map
            ? json['Destination_Port__r']['Name']?.toString()
            : json['Port_of_Destination__c']?.toString();

    return SavedQuotationsModel(
      id: quoteId ?? json['QuoteId']?.toString() ?? json['Id']?.toString(),
      name: json['Quote']?['Name']?.toString() ?? json['quoteName']?.toString(),
      originPortR: originName != null ? PortMaster(name: originName) : null,
      destinationPortR: destName != null ? PortMaster(name: destName) : null,
      totalPrice: _readNum(json['TotalPrice'] ?? json['GrandTotal']),
      goodsValue: _readNum(json['Goods_Value__c'] ?? json['goodsValue']),
      loadType: _readString(json['Load_Type__c'] ?? json['loadType']),
      containerType: _readString(
        json['Container_Type__c'] ?? json['containerType'],
      ),
      containerSize: _readString(
        json['Container_Size__c'] ?? json['containerSize'],
      ),
      modeOfShipment: _readString(
        json['Mode_of_Shipment__c'] ??
            json['mode_of_shipment'] ??
            json['modeOfShipment'],
      ),
      netWeight: _readNum(
        json['Net_Weight__c'] ??
            json['Net_Weight_KGS__c'] ??
            json['weightPerContainer'] ??
            json['netWeight'],
      ),
      grossWeight: _readNum(
        json['Gross_Weight__c'] ??
            json['Gross_Weight_KGS__c'] ??
            json['grossWeight'],
      ),
      commodity: _readString(
        json['Commodity__c'] ??
            json['commodity'] ??
            json['additionalInfo'],
      ),
      expirationDate: json['ExpirationDate']?.toString(),
      status: json['Status']?.toString(),
      currencyIsoCode: json['CurrencyIsoCode']?.toString(),
    );
  }
}

class PortMaster {
  Attributes? attributes;
  String? name;

  PortMaster({this.attributes, this.name});

  factory PortMaster.fromJson(Map<String, dynamic> json) {
    return PortMaster(
      attributes:
          json['attributes'] != null
              ? Attributes.fromJson(json['attributes'])
              : null,
      name: json['Name']?.toString() ?? json['name']?.toString(),
    );
  }
}

class Attributes {
  String? type;
  String? url;

  Attributes({this.type, this.url});

  factory Attributes.fromJson(Map<String, dynamic> json) {
    return Attributes(type: json['type'], url: json['url']);
  }
}
