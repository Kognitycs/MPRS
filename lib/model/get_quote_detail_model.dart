class GetQuoteDetailModel {
  final Attributes? attributes;
  final String? id;
  final bool? isDeleted;
  final String? lineNumber;
  final String? currencyIsoCode;
  final String? createdDate;
  final String? createdById;
  final String? lastModifiedDate;
  final String? lastModifiedById;
  final String? systemModstamp;
  final String? lastViewedDate;
  final String? lastReferencedDate;
  final String? quoteId;
  final String? pricebookEntryId;
  final String? opportunityLineItemId;
  final double? quantity;
  final double? unitPrice;
  final dynamic discount;
  final String? description;
  final dynamic serviceDate;
  final String? product2Id;
  final int? sortOrder;
  final double? listPrice;
  final double? subtotal;
  final double? totalPrice;
  final String? applicationMethod;
  final String? mprsQliCurrency;
  final String? salesPrice;
  final String? test;
  final String? totalPriceCustom; // Total_Price__c
  final String? mprsCurrenciesSetQli;
  final double? discountCustom; // Discount__c
  final double? listPriceCustom;
  final double? buyAmount;
  final String? listPriceFormula;
  final String? lossFormula;
  final String? product;
  final double? tax;
  final String? chargeType;
  final String? finalBuyFormula;
  final String? finalSellFormula;
  final double? finalSellingPrice;
  final double? finalBuyingPrice;

  GetQuoteDetailModel({
    this.attributes,
    this.id,
    this.isDeleted,
    this.lineNumber,
    this.currencyIsoCode,
    this.createdDate,
    this.createdById,
    this.lastModifiedDate,
    this.lastModifiedById,
    this.systemModstamp,
    this.lastViewedDate,
    this.lastReferencedDate,
    this.quoteId,
    this.pricebookEntryId,
    this.opportunityLineItemId,
    this.quantity,
    this.unitPrice,
    this.discount,
    this.description,
    this.serviceDate,
    this.product2Id,
    this.sortOrder,
    this.listPrice,
    this.subtotal,
    this.totalPrice,
    this.applicationMethod,
    this.mprsQliCurrency,
    this.salesPrice,
    this.test,
    this.totalPriceCustom,
    this.mprsCurrenciesSetQli,
    this.discountCustom,
    this.listPriceCustom,
    this.buyAmount,
    this.listPriceFormula,
    this.lossFormula,
    this.product,
    this.tax,
    this.chargeType,
    this.finalBuyFormula,
    this.finalSellFormula,
    this.finalSellingPrice,
    this.finalBuyingPrice,
  });

  static double? _readNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', ''));
  }

  /// Per-unit buy price when available from API.
  double? get buyingUnitPrice =>
      finalBuyingPrice ?? _readNum(finalBuyFormula) ?? buyAmount;

  /// Per-unit sell price — prefer explicit final selling price from API.
  double get sellingUnitPrice =>
      finalSellingPrice ??
      _readNum(finalSellFormula) ??
      _readNum(salesPrice) ??
      unitPrice ??
      listPrice ??
      0;

  /// Line total = final selling price × quantity.
  double get lineAmountByFinalSell =>
      sellingUnitPrice * (quantity ?? 1);

  static String? _readProductName(Map<String, dynamic> json) {
    final direct = json['Product__c'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final product2 = json['Product2'];
    if (product2 is Map) {
      final name = product2['Name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    final productR = json['Product2__r'];
    if (productR is Map) {
      final name = productR['Name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    final pricebookEntry = json['PricebookEntry'];
    if (pricebookEntry is Map) {
      final entryProduct = pricebookEntry['Product2'];
      if (entryProduct is Map) {
        final name = entryProduct['Name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    }

    return json['Description']?.toString();
  }

  static String? _readChargeType(Map<String, dynamic> json) {
    final direct = json['Charge_Type__c'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    return json['ChargeType__c']?.toString();
  }

  static double? _readLineAmount(Map<String, dynamic> json) {
    final custom = json['Total_Price__c'];
    if (custom != null) {
      return double.tryParse(custom.toString().replaceAll(',', ''));
    }
    final total = json['TotalPrice'];
    if (total is num) return total.toDouble();
    return null;
  }

  factory GetQuoteDetailModel.fromJson(Map<String, dynamic> json) {
    return GetQuoteDetailModel(
      attributes: json['attributes'] != null
          ? Attributes.fromJson(json['attributes'])
          : null,
      id: json['Id'],
      isDeleted: json['IsDeleted'],
      lineNumber: json['LineNumber'],
      currencyIsoCode: json['CurrencyIsoCode'],
      createdDate: json['CreatedDate'],
      createdById: json['CreatedById'],
      lastModifiedDate: json['LastModifiedDate'],
      lastModifiedById: json['LastModifiedById'],
      systemModstamp: json['SystemModstamp'],
      lastViewedDate: json['LastViewedDate'],
      lastReferencedDate: json['LastReferencedDate'],
      quoteId: json['QuoteId'],
      pricebookEntryId: json['PricebookEntryId'],
      opportunityLineItemId: json['OpportunityLineItemId'],
      quantity: (json['Quantity'] as num?)?.toDouble(),
      unitPrice: (json['UnitPrice'] as num?)?.toDouble(),
      discount: json['Discount'],
      description: json['Description'],
      serviceDate: json['ServiceDate'],
      product2Id: json['Product2Id'],
      sortOrder: json['SortOrder'],
      listPrice: (json['ListPrice'] as num?)?.toDouble(),
      subtotal: (json['Subtotal'] as num?)?.toDouble(),
      applicationMethod: json['Application_Method__c'],
      mprsQliCurrency: json['MPRS_QLI_Currency__c'],
      salesPrice: json['Sales_Price__c'],
      test: json['Test__c'],
      totalPriceCustom: json['Total_Price__c'],
      mprsCurrenciesSetQli: json['MPRS_Currencies_Set_QLI__c'],
      discountCustom: (json['Discount__c'] as num?)?.toDouble(),
      listPriceCustom: (json['List_Price_Custom__c'] as num?)?.toDouble(),
      buyAmount: (json['Buy_Amount__c'] as num?)?.toDouble(),
      listPriceFormula: json['List_Price_Formula__c'],
      lossFormula: json['Loss_Formula__c'],
      product: _readProductName(json),
      tax: (json['Tax__c'] as num?)?.toDouble(),
      chargeType: _readChargeType(json),
      totalPrice: _readLineAmount(json) ?? (json['TotalPrice'] as num?)?.toDouble(),
      finalBuyFormula: json['Final_Buy_Formula__c'],
      finalSellFormula: json['Final_Sell_Formula__c'],
      finalSellingPrice:
          _readNum(json['finalSellingPrice']) ??
          _readNum(json['Final_Selling_Price__c']) ??
          _readNum(json['Final_Sell_Price__c']),
      finalBuyingPrice:
          _readNum(json['finalBuyingPrice']) ??
          _readNum(json['Final_Buying_Price__c']) ??
          _readNum(json['Final_Buy_Price__c']),
    );
  }
}

class Attributes {
  final String? type;
  final String? url;

  Attributes({this.type, this.url});

  factory Attributes.fromJson(Map<String, dynamic> json) {
    return Attributes(
      type: json['type'],
      url: json['url'],
    );
  }
}