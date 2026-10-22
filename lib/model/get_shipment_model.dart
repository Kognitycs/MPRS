class GetShipmentModel {
  int? status;
  List<Records>? records;

  GetShipmentModel({
    this.status,
    this.records,
  });

  GetShipmentModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];

    if (json['records'] != null) {
      records = <Records>[];

      json['records'].forEach((v) {
        records!.add(Records.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['status'] = status;

    if (records != null) {
      data['records'] =
          records!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class Records {
  Attributes? attributes;

  // --------------------------------------------------------------------------
  // ORDER FIELDS
  // --------------------------------------------------------------------------

  dynamic id;
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
  dynamic arrivalDateC;
  dynamic departureDateC;

  // --------------------------------------------------------------------------
  // QUOTE FIELDS
  // --------------------------------------------------------------------------

  dynamic name;
  dynamic status;
  dynamic expirationDate;
  dynamic createdDate;
  dynamic grandTotal;
  dynamic pdfSavedC;
  dynamic accountId;
  dynamic leadTypeC;
  dynamic containerTypeC;
  dynamic containerSizeC;
  dynamic modeOfShipmentC;
  dynamic netWeightKgsC;
  dynamic grossWeightKgsC;
  dynamic goodsValueC;
  dynamic originPortName;
  dynamic destinationPortName;

  Opportunity? opportunity;
  Account? account;

  Records({
    this.attributes,

    // ORDER
    this.id,
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
    this.arrivalDateC,
    this.departureDateC,

    // QUOTE
    this.name,
    this.status,
    this.expirationDate,
    this.createdDate,
    this.grandTotal,
    this.pdfSavedC,
    this.accountId,
    this.leadTypeC,
    this.containerTypeC,
    this.containerSizeC,
    this.modeOfShipmentC,
    this.netWeightKgsC,
    this.grossWeightKgsC,
    this.goodsValueC,
    this.originPortName,
    this.destinationPortName,
    this.opportunity,
    this.account,
  });

  Records.fromJson(Map<String, dynamic> json) {
    attributes = json['attributes'] != null
        ? Attributes.fromJson(json['attributes'])
        : null;

    // ----------------------------------------------------------------------
    // ORDER
    // ----------------------------------------------------------------------

    id = json['Id'];
    orderNumber = json['OrderNumber'];
    portOfLoadingC = json['Port_of_Loading__c'];
    portOfDestinationC = json['Port_of_Destination__c'];
    vesselNameC = json['Vessel_Name__c'];
    voyageNumberC = json['Voyage_Number__c'];
    trackingStatusC = json['Tracking_Status__c'];
    orderReferenceNumber = json['OrderReferenceNumber'];
    containerNumberC = json['Container_Number__c'];
    bookedDateC = json['Booked_Date__c'];
    pickedUpDateC = json['Picked_Up_Date__c'];
    gatedInDateC = json['Gated_In_Date__c'];
    onBoardDateC = json['On_Board_Date__c'];
    vesselSailedDateC = json['Vessel_Sailed_Date__c'];
    dischargedDateC = json['Discharged_Date__c'];

    transshipmentLoadedDateC =
    json['Transshipment_Loaded_Date__c'];

    transshipmentDischargeDateC =
    json['Transshipment_Discharge_Date__c'];

    clearedDateC = json['Cleared_Date__c'];
    returnedDateC = json['Returned_Date__c'];
    customStatusC = json['Custom_Status__c'];
    arrivalDateC = json['Arrival_Date__c'];
    departureDateC = json['Departure_Date__c'];

    // ----------------------------------------------------------------------
    // QUOTE
    // ----------------------------------------------------------------------

    name = json['Name'];
    status = json['Status'];
    expirationDate = json['ExpirationDate'];
    createdDate =
        json['CreatedDate'] ??
        json['Created_Date__c'] ??
        json['createdDate'] ??
        json['createdAt'] ??
        json['created_at'] ??
        json['LastModifiedDate'] ??
        json['SystemModstamp'];
    grandTotal = json['GrandTotal'];
    pdfSavedC = json['PDF_Saved__c'];
    accountId = json['AccountId'];
    leadTypeC = json['Lead_Type__c'] ?? json['Load_Type__c'];
    final opportunityJson = json['Opportunity'];
    containerTypeC =
        json['Container_Type__c'] ??
        json['containerType'] ??
        json['ContainerType__c'] ??
        (opportunityJson is Map
            ? opportunityJson['Container_Type__c'] ??
                opportunityJson['containerType'] ??
                opportunityJson['ContainerType__c']
            : null);
    containerSizeC =
        json['Container_Size__c'] ??
        json['containerSize'] ??
        json['ContainerSize__c'] ??
        (opportunityJson is Map
            ? opportunityJson['Container_Size__c'] ??
                opportunityJson['containerSize'] ??
                opportunityJson['ContainerSize__c']
            : null);
    modeOfShipmentC =
        json['Mode_of_Shipment__c'] ??
        json['Mode_Of_Shipment__c'] ??
        json['mode_of_shipment'] ??
        json['modeOfShipment'] ??
        (opportunityJson is Map
            ? opportunityJson['Mode_of_Shipment__c'] ??
                opportunityJson['Mode_Of_Shipment__c'] ??
                opportunityJson['mode_of_shipment']
            : null);
    netWeightKgsC = json['Net_Weight_KGS__c'] ?? json['Net_Weight__c'];
    grossWeightKgsC = json['Gross_Weight_KGS__c'] ?? json['Gross_Weight__c'];
    goodsValueC = json['Goods_Value__c'];
    originPortName = json['Origin_Port__r'] is Map
        ? json['Origin_Port__r']['Name']
        : json['Port_of_Loading__c'];
    destinationPortName = json['Destination_Port__r'] is Map
        ? json['Destination_Port__r']['Name']
        : json['Port_of_Destination__c'];

    opportunity = json['Opportunity'] != null
        ? Opportunity.fromJson(json['Opportunity'])
        : null;

    account = json['Account'] != null
        ? Account.fromJson(json['Account'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (attributes != null) {
      data['attributes'] = attributes!.toJson();
    }

    // ----------------------------------------------------------------------
    // ORDER
    // ----------------------------------------------------------------------

    data['Id'] = id;
    data['OrderNumber'] = orderNumber;
    data['Port_of_Loading__c'] = portOfLoadingC;
    data['Port_of_Destination__c'] =
        portOfDestinationC;

    data['Vessel_Name__c'] = vesselNameC;
    data['Voyage_Number__c'] = voyageNumberC;
    data['Tracking_Status__c'] = trackingStatusC;

    data['OrderReferenceNumber'] =
        orderReferenceNumber;

    data['Container_Number__c'] = containerNumberC;
    data['Booked_Date__c'] = bookedDateC;
    data['Picked_Up_Date__c'] = pickedUpDateC;
    data['Gated_In_Date__c'] = gatedInDateC;
    data['On_Board_Date__c'] = onBoardDateC;
    data['Vessel_Sailed_Date__c'] = vesselSailedDateC;
    data['Discharged_Date__c'] = dischargedDateC;

    data['Transshipment_Loaded_Date__c'] =
        transshipmentLoadedDateC;

    data['Transshipment_Discharge_Date__c'] =
        transshipmentDischargeDateC;

    data['Cleared_Date__c'] = clearedDateC;
    data['Returned_Date__c'] = returnedDateC;
    data['Custom_Status__c'] = customStatusC;
    data['Arrival_Date__c'] = arrivalDateC;
    data['Departure_Date__c'] = departureDateC;

    // ----------------------------------------------------------------------
    // QUOTE
    // ----------------------------------------------------------------------

    data['Name'] = name;
    data['Status'] = status;
    data['ExpirationDate'] = expirationDate;
    data['GrandTotal'] = grandTotal;
    data['PDF_Saved__c'] = pdfSavedC;
    data['AccountId'] = accountId;

    if (opportunity != null) {
      data['Opportunity'] =
          opportunity!.toJson();
    }

    if (account != null) {
      data['Account'] = account!.toJson();
    }

    return data;
  }
}

class Opportunity {
  dynamic name;

  Opportunity({
    this.name,
  });

  Opportunity.fromJson(Map<String, dynamic> json) {
    name = json['Name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['Name'] = name;

    return data;
  }
}

class Account {
  dynamic name;

  Account({
    this.name,
  });

  Account.fromJson(Map<String, dynamic> json) {
    name = json['Name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['Name'] = name;

    return data;
  }
}

class Attributes {
  dynamic type;
  dynamic url;

  Attributes({
    this.type,
    this.url,
  });

  Attributes.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    data['type'] = type;
    data['url'] = url;

    return data;
  }
}