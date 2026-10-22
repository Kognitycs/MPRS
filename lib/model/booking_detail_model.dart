
class BookingDetailModel {
  List<BookingItem>? items;

  BookingDetailModel({this.items});

  BookingDetailModel.fromJson(Map<String, dynamic> json) {
    if (json['items'] != null) {
      items = <BookingItem>[];
      json['items'].forEach((v) {
        items!.add(BookingItem.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (items != null) {
      data['items'] = items!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BookingItem {
  String? id;
  String? product2Id;
  bool? isDeleted;
  String? orderId;
  String? pricebookEntryId;
  String? originalOrderItemId;
  String? quoteLineItemId;
  double? availableQuantity;
  double? quantity;
  String? currencyIsoCode;
  double? unitPrice;
  double? listPrice;
  double? totalPrice;
  String? serviceDate;
  String? endDate;
  String? description;
  String? createdDate;
  String? createdById;
  String? lastModifiedDate;
  String? lastModifiedById;
  String? systemModstamp;
  String? orderItemNumber;
  String? mprsCurrenciesC;
  String? totalPriceC; // "USD 1890" - Best for UI
  String? productC;    // "OCEAN FREIGHT"
  String? listPriceFormulaC;
  String? salesPriceC;
  double? tax;

  BookingItem({
    this.id,
    this.product2Id,
    this.isDeleted,
    this.orderId,
    this.pricebookEntryId,
    this.originalOrderItemId,
    this.quoteLineItemId,
    this.availableQuantity,
    this.quantity,
    this.currencyIsoCode,
    this.unitPrice,
    this.listPrice,
    this.totalPrice,
    this.serviceDate,
    this.endDate,
    this.description,
    this.createdDate,
    this.createdById,
    this.lastModifiedDate,
    this.lastModifiedById,
    this.systemModstamp,
    this.orderItemNumber,
    this.mprsCurrenciesC,
    this.totalPriceC,
    this.productC,
    this.listPriceFormulaC,
    this.salesPriceC,
    this.tax,
  });

  BookingItem.fromJson(Map<String, dynamic> json) {
    id = json['Id'];
    product2Id = json['Product2Id'];
    isDeleted = json['IsDeleted'];
    orderId = json['OrderId'];
    pricebookEntryId = json['PricebookEntryId'];
    originalOrderItemId = json['OriginalOrderItemId'];
    quoteLineItemId = json['QuoteLineItemId'];

    // Safety: Handling both int and double from API
    availableQuantity = (json['AvailableQuantity'] as num?)?.toDouble();
    quantity = (json['Quantity'] as num?)?.toDouble();
    currencyIsoCode = json['CurrencyIsoCode'];
    unitPrice = (json['UnitPrice'] as num?)?.toDouble();
    listPrice = (json['ListPrice'] as num?)?.toDouble();
    totalPrice = (json['TotalPrice'] as num?)?.toDouble();

    serviceDate = json['ServiceDate'];
    endDate = json['EndDate'];
    description = json['Description'];
    createdDate = json['CreatedDate'];
    createdById = json['CreatedById'];
    lastModifiedDate = json['LastModifiedDate'];
    lastModifiedById = json['LastModifiedById'];
    systemModstamp = json['SystemModstamp'];
    orderItemNumber = json['OrderItemNumber'];
    mprsCurrenciesC = json['MPRS_Currencies__c'];
    totalPriceC = json['Total_Price__c'];
    productC = json['Product__c'];
    list_price_formula_c: json['List_Price_Formula__c']; // Correcting naming
    listPriceFormulaC = json['List_Price_Formula__c'];
    salesPriceC = json['Sales_Price__c'];
    tax = (json['Tax__c'] as num?)?.toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Id'] = id;
    data['Product2Id'] = product2Id;
    data['IsDeleted'] = isDeleted;
    data['OrderId'] = orderId;
    data['PricebookEntryId'] = pricebookEntryId;
    data['OriginalOrderItemId'] = originalOrderItemId;
    data['QuoteLineItemId'] = quoteLineItemId;
    data['AvailableQuantity'] = availableQuantity;
    data['Quantity'] = quantity;
    data['CurrencyIsoCode'] = currencyIsoCode;
    data['UnitPrice'] = unitPrice;
    data['ListPrice'] = listPrice;
    data['TotalPrice'] = totalPrice;
    data['ServiceDate'] = serviceDate;
    data['EndDate'] = endDate;
    data['Description'] = description;
    data['CreatedDate'] = createdDate;
    data['CreatedById'] = createdById;
    data['LastModifiedDate'] = lastModifiedDate;
    data['LastModifiedById'] = lastModifiedById;
    data['SystemModstamp'] = systemModstamp;
    data['OrderItemNumber'] = orderItemNumber;
    data['MPRS_Currencies__c'] = mprsCurrenciesC;
    data['Total_Price__c'] = totalPriceC;
    data['Product__c'] = productC;
    data['List_Price_Formula__c'] = listPriceFormulaC;
    data['Sales_Price__c'] = salesPriceC;
    data['Tax__c'] = tax;
    return data;
  }
}