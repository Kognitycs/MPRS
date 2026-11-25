import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/screens/quote/price_calculation.dart';

/// Editable quote line row for internal users (Search Rates → Price step).
class InternalQuoteLineEdit {
  final String product2Id;
  final String pricebookEntryId;
  final String? pricebook2Id;
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
    this.pricebook2Id,
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

String _currencyForEntry(PricebookEntryModel entry) {
  final raw = entry.mprsCurrencyC?.trim() ?? '';
  if (raw.isNotEmpty) return raw.toUpperCase();
  return 'USD';
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

double defaultTaxPercentForProduct(String productName) {
  return productName.toUpperCase().contains('OCEAN FREIGHT') ? 18 : 5;
}

/// Most frequent non-empty `Pricebook2Id` on rows for this MLO (search results).
String? dominantPricebook2IdForMlo(
  List<PricebookEntryModel> allEntries,
  String mlo,
) {
  final counts = <String, int>{};
  final m = mlo.trim();
  for (final e in allEntries) {
    if (e.mloCode.trim() != m) continue;
    final pb = pricebook2IdForEntry(e, allEntries);
    if (pb == null || pb.isEmpty) continue;
    counts[pb] = (counts[pb] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String? pricebook2IdForEntry(
  PricebookEntryModel entry,
  List<PricebookEntryModel> allEntries,
) {
  final direct = entry.pricebook2Id?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  for (final e in allEntries) {
    if (e.id == entry.id) {
      final id = e.pricebook2Id?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
  }
  return null;
}

/// Pricebook for the selected container's ocean freight row (same MLO / PB2).
String? anchorPricebook2Id({
  required List<PricebookEntryModel> allEntries,
  required String selectedContainerSize,
  PricebookEntryModel? anchorEntry,
}) {
  if (anchorEntry != null) {
    final fromAnchor = pricebook2IdForEntry(anchorEntry, allEntries);
    if (fromAnchor != null && fromAnchor.isNotEmpty) return fromAnchor;
  }

  final selectedSize = _normalizeSize(selectedContainerSize.trim());
  for (final e in allEntries) {
    if (!e.productName.toUpperCase().contains('OCEAN FREIGHT')) continue;
    if (selectedSize.isNotEmpty) {
      final apiSize = _normalizeSize(e.containerSize);
      if (apiSize.isNotEmpty &&
          !apiSize.contains(selectedSize) &&
          !selectedSize.contains(apiSize)) {
        continue;
      }
    }
    final id = e.pricebook2Id?.trim();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

/// Same entry filter as [GetQuoteScreen] line items for a container size.
List<InternalQuoteLineEdit> buildInternalQuoteLineEdits({
  required List<PricebookEntryModel> allEntries,
  required String selectedContainerSize,
  required int quantity,
  required String userType,
  double? accountMarginPct,
  PricebookEntryModel? anchorEntry,
}) {
  final selectedSize = _normalizeSize(selectedContainerSize.trim());
  final anchorMlo = anchorEntry?.mloCode.trim() ?? '';

  // All MLO charges for container size (Edit price list — same as legacy quote build).
  final entries =
      allEntries.where((e) {
        if (e.productName.toLowerCase().contains('thc')) return false;
        if (anchorMlo.isNotEmpty && e.mloCode.trim() != anchorMlo) return false;
        if (selectedSize.isEmpty) return true;
        final apiSize = _normalizeSize(e.containerSize);
        if (apiSize.isEmpty) return true;
        return apiSize.contains(selectedSize) || selectedSize.contains(apiSize);
      }).toList();

  if (entries.isEmpty) return [];

  final oceanRows = () {
    if (anchorEntry != null &&
        anchorEntry.productName.toUpperCase().contains('OCEAN FREIGHT')) {
      return [anchorEntry];
    }
    return entries
        .where((e) => e.productName.toUpperCase().contains('OCEAN FREIGHT'))
        .toList();
  }();
  final otherRows =
      entries
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
      pricebook2Id: pricebook2IdForEntry(entry, allEntries),
      productName: entry.productName,
      quantity: qty,
      currency: _currencyForEntry(entry),
      buyPrice: pricing.buyPrice,
      sellPrice: pricing.sellPrice,
      isMarginProduct: entry.isMarginProduct,
      taxPercent: defaultTaxPercentForProduct(entry.productName),
    );
  }).toList();
}
