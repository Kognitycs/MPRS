class GetBookingListModelNew {
  int? status;

  List<Records>? bookings;

  GetBookingListModelNew({this.status, this.bookings});

  GetBookingListModelNew.fromJson(Map<String, dynamic> json) {
    status = json['status'];

    if (json['bookings'] != null) {
      bookings = <Records>[];

      json['bookings'].forEach((v) {
        bookings!.add(Records.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['status'] = status;

    if (bookings != null) {
      data['bookings'] = bookings!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class Records {
  Attributes? attributes;

  dynamic id;

  dynamic quoteId;

  dynamic orderNumber;

  dynamic portOfLoadingC;

  dynamic portOfDestinationC;

  dynamic vesselNameC;

  dynamic voyageNumberC;

  dynamic trackingStatusC;

  dynamic orderReferenceNumber;

  dynamic containerNumberC;

  dynamic bookedDateC;

  dynamic pickedUpDateC;

  dynamic gatedInDateC;

  dynamic onBoardDateC;

  dynamic vesselSailedDateC;

  dynamic dischargedDateC;

  dynamic transshipmentLoadedDateC;

  dynamic transshipmentDischargeDateC;

  dynamic clearedDateC;

  dynamic returnedDateC;

  dynamic customStatusC;

  dynamic quoteName;

  dynamic opportunityName;

  dynamic accountName;

  dynamic createdDate;

  dynamic expirationDate;

  dynamic arrivalDateC;

  dynamic departureDateC;

  dynamic totalAmount;

  dynamic currencyIsoCode;

  dynamic leadTypeC;

  dynamic containerTypeC;

  dynamic containerSizeC;

  dynamic modeOfShipmentC;

  dynamic commodityC;

  dynamic containerQuantityC;

  dynamic blNumberC;

  dynamic grossWeightC;

  dynamic routingC;

  Records({
    this.attributes,
    this.id,
    this.quoteId,
    this.orderNumber,
    this.portOfLoadingC,
    this.portOfDestinationC,
    this.vesselNameC,
    this.voyageNumberC,
    this.trackingStatusC,
    this.orderReferenceNumber,
    this.containerNumberC,
    this.bookedDateC,
    this.pickedUpDateC,
    this.gatedInDateC,
    this.onBoardDateC,
    this.vesselSailedDateC,
    this.dischargedDateC,
    this.transshipmentLoadedDateC,
    this.transshipmentDischargeDateC,
    this.clearedDateC,
    this.returnedDateC,
    this.customStatusC,
    this.quoteName,
    this.opportunityName,
    this.accountName,
    this.createdDate,
    this.expirationDate,
    this.arrivalDateC,
    this.departureDateC,
    this.totalAmount,
    this.currencyIsoCode,
    this.leadTypeC,
    this.containerTypeC,
    this.containerSizeC,
    this.modeOfShipmentC,
    this.commodityC,
    this.containerQuantityC,
    this.blNumberC,
    this.grossWeightC,
    this.routingC,
  });

  /// Latest bookings and quotes first.
  static List<Records> sortNewestFirst(List<Records> list) {
    final sorted = List<Records>.from(list);
    sorted.sort((a, b) {
      final da = a._sortDate;
      final db = b._sortDate;
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return (b.id?.toString() ?? '').compareTo(a.id?.toString() ?? '');
    });
    return sorted;
  }

  /// Newest created or booked time. Expiration is not used, so an older
  /// quote with a later expiry does not jump above a quote just created.
  DateTime? get _sortDate {
    final created = _parseSortDate(createdDate);
    final booked = _parseSortDate(bookedDateC);
    if (created != null && booked != null) {
      return created.isAfter(booked) ? created : booked;
    }
    return created ?? booked;
  }

  static DateTime? _parseSortDate(dynamic raw) {
    var text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    text = text.replaceFirst(' ', 'T');
    text = text.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (match) => '${match[1]}:${match[2]}',
    );
    return DateTime.tryParse(text)?.toLocal();
  }

  /// Order / reference shown on booked cards (# prefix added in UI).
  String get displayOrderNumber {
    for (final raw in [orderNumber, orderReferenceNumber, quoteName]) {
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Secondary line under the order number (vessel, MLO, or opportunity).
  String get displaySubtitle {
    for (final raw in [vesselNameC, voyageNumberC, opportunityName]) {
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Best available booked / created date for list cards.
  String get displayBookedDate {
    for (final raw in [
      bookedDateC,
      createdDate,
      expirationDate,
      departureDateC,
      arrivalDateC,
      vesselSailedDateC,
      onBoardDateC,
      pickedUpDateC,
    ]) {
      final formatted = formatListDate(raw);
      if (formatted != null) return formatted;
    }
    return '';
  }

  /// Formatted amount with currency for booked cards.
  String get displayAmount {
    final amount = _parseAmount(totalAmount);
    if (amount == null) return '—';
    final currency = currencyIsoCode?.toString().trim() ?? '';
    final formatted = _formatListAmount(amount);
    if (currency.isNotEmpty) return '$currency $formatted';
    return formatted;
  }

  static String? formatListDate(dynamic raw) => _formatListDate(raw);

  static String? _formatListDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    try {
      final dt = DateTime.parse(text.split('T').first);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return text;
    }
  }

  static num? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    final text = raw.toString().trim().replaceAll(',', '');
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }

  static String _formatListAmount(num value) {
    if (value == value.roundToDouble()) {
      final whole = value.round().toString();
      return whole.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
    }
    return value.toStringAsFixed(2);
  }

  Records.fromJson(Map<String, dynamic> json) {
    attributes =
        json['attributes'] != null
            ? Attributes.fromJson(json['attributes'])
            : null;

    id = json['Id'];

    quoteName = json['Name'];
    final opportunity = json['Opportunity'];
    if (opportunity is Map) {
      opportunityName = opportunity['Name'];
    } else {
      opportunityName = json['Opportunity.Name'];
    }
    final account = json['Account'];
    if (account is Map) {
      accountName = account['Name'];
    } else {
      accountName = json['Account.Name'] ?? json['accountName'];
    }
    createdDate =
        json['CreatedDate'] ??
        json['Created_Date__c'] ??
        json['createdDate'] ??
        json['createdAt'] ??
        json['created_at'] ??
        json['LastModifiedDate'] ??
        json['SystemModstamp'];
    expirationDate = json['ExpirationDate'];

    /// QUOTE ID
    quoteId =
        json['QuoteId'] ??
        json['Quote__c'] ??
        json['quoteId'] ??
        json['quote_id'] ??
        (json['Quote'] is Map ? json['Quote']['Id'] : null) ??
        (json['Quote__r'] is Map ? json['Quote__r']['Id'] : null);

    /// ORDER NUMBER
    orderNumber = json['OrderNumber'] ?? json['OrderReferenceNumber'];

    /// ORIGIN PORT
    portOfLoadingC =
        json['Origin_Port__r']?['Name'] ??
        json['Port_of_Loading__c'] ??
        json['Port_of_Loading__r']?['Name'];

    /// DESTINATION PORT
    portOfDestinationC =
        json['Destination_Port__r']?['Name'] ??
        json['Port_of_Destination__c'] ??
        json['Port_of_Destination__r']?['Name'];

    /// MLO / vessel name
    vesselNameC = json['MLO_Name__r']?['Name'] ?? json['Vessel_Name__c'];

    voyageNumberC = json['Voyage_Number__c'];

    trackingStatusC = json['Tracking_Status__c'] ?? json['Status'];

    orderReferenceNumber = json['OrderReferenceNumber'];

    containerNumberC = json['Container_Number__c'];

    bookedDateC =
        json['Booked_Date__c'] ??
        json['bookedDate'] ??
        json['booked_date'] ??
        json['BookedDate'] ??
        json['Booking_Date__c'] ??
        json['bookingDate'] ??
        json['EffectiveDate'] ??
        json['CreatedDate'] ??
        json['Created_Date__c'] ??
        json['createdAt'] ??
        json['created_at'];

    pickedUpDateC = json['Picked_Up_Date__c'];

    gatedInDateC = json['Gated_In_Date__c'];

    onBoardDateC = json['On_Board_Date__c'];

    vesselSailedDateC = json['Vessel_Sailed_Date__c'];

    dischargedDateC = json['Discharged_Date__c'];

    transshipmentLoadedDateC = json['Transshipment_Loaded_Date__c'];

    transshipmentDischargeDateC = json['Transshipment_Discharge_Date__c'];

    clearedDateC = json['Cleared_Date__c'];

    returnedDateC = json['Returned_Date__c'];

    customStatusC = json['Custom_Status__c'];

    arrivalDateC = json['Arrival_Date__c'];
    departureDateC = json['Departure_Date__c'];

    totalAmount =
        json['TotalAmount'] ?? json['GrandTotal'] ?? json['TotalPrice'];
    currencyIsoCode = json['CurrencyIsoCode'] ?? json['MPRS_Currency__c'];

    leadTypeC =
        json['Lead_Type__c'] ??
        json['Load_Type__c'] ??
        json['LoadType__c'] ??
        json['loadType'];

    final opportunityMap = json['Opportunity'];

    containerTypeC =
        json['Container_Type__c'] ??
        json['containerType'] ??
        json['ContainerType__c'] ??
        (opportunityMap is Map
            ? opportunityMap['Container_Type__c'] ??
                opportunityMap['containerType'] ??
                opportunityMap['ContainerType__c']
            : null);

    containerSizeC =
        json['Container_Size__c'] ??
        json['containerSize'] ??
        json['ContainerSize__c'] ??
        (opportunityMap is Map
            ? opportunityMap['Container_Size__c'] ??
                opportunityMap['containerSize'] ??
                opportunityMap['ContainerSize__c']
            : null);
    modeOfShipmentC =
        json['Mode_of_Shipment__c'] ??
        json['Mode_Of_Shipment__c'] ??
        json['mode_of_shipment'] ??
        json['modeOfShipment'] ??
        (opportunityMap is Map
            ? opportunityMap['Mode_of_Shipment__c'] ??
                opportunityMap['Mode_Of_Shipment__c'] ??
                opportunityMap['mode_of_shipment']
            : null);

    leadTypeC ??= _pick(json, const [
      'Lead_Type__c',
      'Load_Type__c',
      'loadType',
    ]);
    containerTypeC ??= _pick(json, const [
      'Container_Type__c',
      'containerType',
    ]);
    containerSizeC ??= _pick(json, const [
      'Container_Size__c',
      'containerSize',
      'container_size',
      'ContainerSize',
      'Size__c',
    ]);
    modeOfShipmentC ??= _pick(json, const [
      'Mode_of_Shipment__c',
      'modeOfShipment',
    ]);
    commodityC = _pick(json, const [
      'Commodity__c',
      'commodity',
      'Commodity_Description__c',
      'additionalInfo',
      'additional_info',
      'Additional_Info__c',
      'Additional_Information__c',
      'Cargo_Description__c',
      'Goods_Description__c',
    ]);
    containerQuantityC = _pick(json, const [
      'Number_of_Containers__c',
      'No_of_Containers__c',
      'Container_Quantity__c',
      'containerQuantity',
      'numberOfContainers',
    ]);
    blNumberC = _pick(json, const [
      'BL_Number__c',
      'Bill_of_Lading__c',
      'Bill_of_Lading_Number__c',
      'BOL_Number__c',
      'HBL__c',
      'MBL__c',
      'blNumber',
      'billOfLading',
    ]);
    grossWeightC = _pick(json, const [
      'Gross_Weight_KGS__c',
      'Gross_Weight__c',
      'Net_Weight_KGS__c',
      'weightPerContainer',
      'grossWeight',
    ]);
    routingC = _pick(json, const [
      'Routing__c',
      'routing',
      'Direct_Indirect_Routing__c',
      'Shipment_Routing__c',
      'Via_Port__c',
    ]);
  }

  static String? _pick(Map<String, dynamic> json, List<String> keys) {
    final maps = <Map<String, dynamic>>[json];
    for (final nestKey in [
      'Quote__r',
      'Quote',
      'quote',
      'Opportunity',
      'Product2',
    ]) {
      final nest = json[nestKey];
      if (nest is Map) maps.add(Map<String, dynamic>.from(nest));
    }
    for (final map in maps) {
      for (final key in keys) {
        final raw = map[key];
        if (raw is Map) {
          final name = (raw['Name'] ?? raw['name'])?.toString().trim() ?? '';
          if (name.isNotEmpty && name != 'null') return name;
          continue;
        }
        final text = raw?.toString().trim() ?? '';
        if (text.isNotEmpty && text != 'null') return text;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    if (attributes != null) {
      data['attributes'] = attributes!.toJson();
    }

    data['Id'] = id;

    data['QuoteId'] = quoteId;

    data['OrderNumber'] = orderNumber;

    data['Port_of_Loading__c'] = portOfLoadingC;

    data['Port_of_Destination__c'] = portOfDestinationC;

    data['Vessel_Name__c'] = vesselNameC;

    data['Voyage_Number__c'] = voyageNumberC;

    data['Tracking_Status__c'] = trackingStatusC;

    data['OrderReferenceNumber'] = orderReferenceNumber;

    data['Container_Number__c'] = containerNumberC;

    data['Booked_Date__c'] = bookedDateC;

    data['Picked_Up_Date__c'] = pickedUpDateC;

    data['Gated_In_Date__c'] = gatedInDateC;

    data['On_Board_Date__c'] = onBoardDateC;

    data['Vessel_Sailed_Date__c'] = vesselSailedDateC;

    data['Discharged_Date__c'] = dischargedDateC;

    data['Transshipment_Loaded_Date__c'] = transshipmentLoadedDateC;

    data['Transshipment_Discharge_Date__c'] = transshipmentDischargeDateC;

    data['Cleared_Date__c'] = clearedDateC;

    data['Returned_Date__c'] = returnedDateC;

    data['Custom_Status__c'] = customStatusC;

    data['Arrival_Date__c'] = arrivalDateC;
    data['Departure_Date__c'] = departureDateC;

    data['TotalAmount'] = totalAmount;
    data['CurrencyIsoCode'] = currencyIsoCode;
    data['Lead_Type__c'] = leadTypeC;
    data['Container_Type__c'] = containerTypeC;
    data['Container_Size__c'] = containerSizeC;
    data['Mode_of_Shipment__c'] = modeOfShipmentC;
    data['Commodity__c'] = commodityC;
    data['Number_of_Containers__c'] = containerQuantityC;
    data['BL_Number__c'] = blNumberC;
    data['Gross_Weight_KGS__c'] = grossWeightC;
    data['Routing__c'] = routingC;

    return data;
  }
}

class Attributes {
  dynamic type;

  dynamic url;

  Attributes({this.type, this.url});

  Attributes.fromJson(Map<String, dynamic> json) {
    type = json['type'];

    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['type'] = type;

    data['url'] = url;

    return data;
  }
}
