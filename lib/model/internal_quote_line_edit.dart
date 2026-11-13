import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/screens/quote/price_calculation.dart';

/// Editable quote line row for internal users (Search Rates → Price step).
class InternalQuoteLineEdit {
  final String product2Id;
  final String pricebookEntryId;
  final String productName;
  final int quantity;
  final String currency;
  final double buyPrice;
  final bool isMarginProduct;
  final String chargeType;
  double sellPrice;
  double taxPercent;

  InternalQuoteLineEdit({
    required this.product2Id,
    required this.pricebookEntryId,
    required this.productName,
    required this.quantity,
    required this.currency,
    required this.buyPrice,
    required this.sellPrice,
    required this.isMarginProduct,
    this.chargeType = 'Origin Charges',
    this.taxPercent = 0,
  });

  bool get sellBelowBuy => sellPrice < buyPrice - 0.001;
}

String _normalizeSize(String value) {
  return value
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('\\', '')
      .replaceAll('’', "'")
      .replaceAll('"', '')
      .trim();
}

/// Same entry filter as [GetQuoteScreen] line items for a container size.
List<InternalQuoteLineEdit> buildInternalQuoteLineEdits({
  required List<PricebookEntryModel> allEntries,
  required String selectedContainerSize,
  required int quantity,
  required String userType,
  double? accountMarginPct,
}) {
  final selectedSize = _normalizeSize(selectedContainerSize.trim());

  final entries = allEntries.where((e) {
    if (e.productName.toLowerCase().contains('thc')) return false;
    if (selectedSize.isEmpty) return true;
    final apiSize = _normalizeSize(e.containerSize);
    if (apiSize.isEmpty) return true;
    return apiSize.contains(selectedSize) || selectedSize.contains(apiSize);
  }).toList();

  if (entries.isEmpty) return [];

  final oceanRows = entries
      .where((e) => e.productName.toUpperCase().contains('OCEAN FREIGHT'))
      .toList();
  final otherRows = entries
      .where((e) => !e.productName.toUpperCase().contains('OCEAN FREIGHT'))
      .toList()
    ..sort((a, b) => a.productName.compareTo(b.productName));

  final sorted = [...oceanRows, ...otherRows];
  final qty = quantity <= 0 ? 1 : quantity;

  return sorted.map((entry) {
    final pricing = PricingCalculator.calculate(
      entry: entry,
      userType: userType,
      accountMarginPct: accountMarginPct,
      forceMargin: entry.isMarginProduct,
    );
    return InternalQuoteLineEdit(
      product2Id: entry.product2Id ?? '',
      pricebookEntryId: entry.id,
      productName: entry.productName,
      quantity: qty,
      currency: entry.mprsCurrencyC?.isNotEmpty == true
          ? entry.mprsCurrencyC!
          : 'USD',
      buyPrice: pricing.buyPrice,
      sellPrice: pricing.sellPrice,
      isMarginProduct: entry.isMarginProduct,
    );
  }).toList();
}
