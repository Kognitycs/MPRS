class GetBookingListModel {
  int? status;
  List<Bookings>? bookings;

  GetBookingListModel({this.status, this.bookings});

  GetBookingListModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['bookings'] != null) {
      bookings = <Bookings>[];
      json['bookings'].forEach((v) {
        bookings!.add(new Bookings.fromJson(v));
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

class Bookings {
  Attributes? attributes;
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

  Bookings(
      {this.attributes,
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
        this.returnedDateC});

  Bookings.fromJson(Map<String, dynamic> json) {
    attributes = json['attributes'] != null
        ? new Attributes.fromJson(json['attributes'])
        : null;
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
    transshipmentLoadedDateC = json['Transshipment_Loaded_Date__c'];
    transshipmentDischargeDateC = json['Transshipment_Discharge_Date__c'];
    clearedDateC = json['Cleared_Date__c'];
    returnedDateC = json['Returned_Date__c'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (attributes != null) {
      data['attributes'] = attributes!.toJson();
    }
    data['Id'] = id;
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
