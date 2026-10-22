import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/screens/quote/price_calculation.dart';

// ─── simple data class for one charge row ────────────────────────────────────
class _ChargeRow {
  final String name;
  final double unitPrice;
  final double sellPrice; // calculated sell price (= unitPrice for non-margin products)
  final String currency;
  _ChargeRow({
    required this.name,
    required this.unitPrice,
    required this.sellPrice,
    required this.currency,
  });
}

class ContainerSizeSelectionScreen extends StatefulWidget {
  final String origin;
  final String destination;
  final String routing;
  final String transitTime;
  final double unitPrice;
  final void Function(String? selectedLoadType)? onConfirm;
  final List<String> availableSizes;
  final Function(String selectedSize)? onSizeSelected;
  final int? numberOfContainers;
  final double? netWeightPerContainer;

  /// Pricebook entries for each available size — used to look up the
  /// matching entry (unitPrice, etc.) when the user taps a size chip.
  final List<PricebookEntryModel>? pricebookEntries;

  /// Exact Salesforce Container_Type__c value for the route
  /// (e.g. "Standard(Dry Container)", "Haz", "Open Top").
  /// Used when fetching the full charge list from pricebook/for/ports.
  final String? containerType;

  /// Logged-in user type — "VVIP" | "VIP" | "External" (case-insensitive).
  /// Used by PricingCalculator to compute sell price.
  final String userType;

  /// Account margin percentage (e.g. 10.0 → 10%). null when not configured.
  final double? accountMarginPct;

  const ContainerSizeSelectionScreen({
    Key? key,
    required this.origin,
    required this.destination,
    this.routing = 'Direct',
    required this.transitTime,
    required this.unitPrice,
    this.onConfirm,
    required this.availableSizes,
    this.onSizeSelected,
    this.numberOfContainers,
    this.netWeightPerContainer,
    this.pricebookEntries,
    this.containerType,
    this.userType = 'External',
    this.accountMarginPct,
  }) : super(key: key);

  @override
  State<ContainerSizeSelectionScreen> createState() =>
      _ContainerSizeSelectionScreenState();
}

class _ContainerSizeSelectionScreenState
    extends State<ContainerSizeSelectionScreen> {
  int? selectedSize;
  late final List<String> sizes;

  // ── Price breakdown state ──────────────────────────────────────────────────
  bool _accordionOpen = true;
  bool _chargesLoading = false;
  List<_ChargeRow> _charges = [];
  PricebookEntryModel? _selectedEntry;

  String? get selectedLoadType =>
      selectedSize != null ? sizes[selectedSize!] : null;

  String mapContainerSizeForApi(String size) {
    const mapping = {
      "20'": "20'",
      "40'HC": "40'HC",
      "45'HC": "45'HC",
      "40GP": "40GP",
      "20 TANK": "20 TANK",
      "40 TANK": "40 TANK",
      "20 TANK (SOC)": "20 TANK (SOC)",
      "40 TANK (SOC)": "40 TANK (SOC)",
      "20 REEFER STANDARD": "20 REEFER STANDARD",
      "40 REEFER HIGH CUBE": "40 REEFER HIGH CUBE",
      "40 REEFER STANDARD (SOC)": "40 REEFER STANDARD (SOC)",
      "20 FLAT": "20 FLAT",
      "40 FLAT STANDARD": "40 FLAT STANDARD",
      "40 FLAT HIGH": "40 FLAT HIGH",
      "20'HD(ODO)": "20'HD(ODO)",
    };
    return mapping[size] ?? size;
  }

  @override
  void initState() {
    super.initState();
    sizes =
        widget.availableSizes.where((e) => e.toUpperCase() != 'LCL').toList();
  }

  // ─── build breakdown rows from already-loaded pricebookEntries ─────────────
  //
  // No extra API call — all charge records (OCEAN FREIGHT, THC, DO FEE, etc.)
  // for this MLO were already fetched by the main controller call and passed in
  // via widget.pricebookEntries.  We just filter by containerSize here.

  Future<void> _loadCharges(PricebookEntryModel entry) async {
    if (!mounted) return;
    setState(() {
      _chargesLoading = true;
      _charges = [];
      _selectedEntry = entry;
    });

    final selectedSize = entry.containerSize; // e.g. "20'" or "40'HC"

    debugPrint('💰 [Breakdown] userType="${widget.userType}" '
        'accountMarginPct=${widget.accountMarginPct}% '
        'selectedSize="$selectedSize" '
        'totalEntries=${widget.pricebookEntries?.length ?? 0}');

    // Filter all records for this MLO by the selected container size
    final matching =
        (widget.pricebookEntries ?? [])
            .where((e) => e.containerSize == selectedSize)
            .toList();

    debugPrint('💰 [Breakdown] matching records for "$selectedSize": ${matching.length}');

    // OCEAN FREIGHT first, then other charges alphabetically
    final oceanRows =
        matching
            .where((e) => e.productName.toUpperCase().contains('OCEAN FREIGHT'))
            .toList();
    final otherRows =
        matching
            .where(
              (e) => !e.productName.toUpperCase().contains('OCEAN FREIGHT'),
            )
            .toList()
          ..sort((a, b) => a.productName.compareTo(b.productName));

    _ChargeRow _toRow(PricebookEntryModel e) {
      final double calculatedSell;
      if (e.isMarginProduct) {
        final result = PricingCalculator.calculate(
          entry: e,
          userType: widget.userType,
          accountMarginPct: widget.accountMarginPct,
          forceMargin: true,
        );
        calculatedSell = result.sellPrice;
        debugPrint(
          '💰 [Breakdown] ${e.productName} | isMarginProduct=true | '
          'unitPrice=${e.unitPrice} suggestedMargin=${e.suggestedMarginC} '
          'override=${e.overrideAccountMarginC} '
          'acctMarginVal=${result.accountMarginValue.toStringAsFixed(2)} → '
          'sellPrice=${result.sellPrice}',
        );
      } else {
        calculatedSell = e.unitPrice; // non-margin products: sell = unit price
        debugPrint(
          '💰 [Breakdown] ${e.productName} | isMarginProduct=false | '
          'unitPrice=${e.unitPrice} → sellPrice=${e.unitPrice} (no markup)',
        );
      }
      return _ChargeRow(
        name: e.productName.isNotEmpty ? e.productName : 'OCEAN FREIGHT',
        unitPrice: e.unitPrice,
        sellPrice: calculatedSell,
        currency: e.mprsCurrencyC?.isNotEmpty == true ? e.mprsCurrencyC! : 'USD',
      );
    }

    final rows = [...oceanRows, ...otherRows].map(_toRow).toList();

    // Fallback: show at least the selected entry itself
    if (rows.isEmpty) {
      rows.add(_toRow(entry));
    }

    if (mounted) {
      setState(() {
        _charges = rows;
        _chargesLoading = false;
      });
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Based On Your Selection',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF222222),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF222222),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Origin / Destination row ─────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _portIcon(),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.origin,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 1.5,
                      color: const Color(0xFFBDBDBD),
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.destination,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        _portIcon(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Routing: ${widget.routing.isEmpty ? 'Direct' : widget.routing}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Transit time ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Estimated Transit Time: ${widget.transitTime.isEmpty ? "NA" : widget.transitTime}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Disclaimer ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.main),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.main,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rates are subject to equipment availability, carrier schedule changes, '
                        'final cargo details, and applicable surcharges at the time of booking confirmation.',
                        style: TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Select Container Size ────────────────────────────────────
              const Text(
                'Select Container Size',
                style: TextStyle(
                  color: AppColors.main,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(sizes.length, (i) {
                  final isSelected = selectedSize == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedSize = i);
                      widget.onSizeSelected?.call(
                        mapContainerSizeForApi(sizes[i]),
                      );

                      // Find the matching pricebook entry for this size and fetch charges
                      final entry = widget.pricebookEntries?.firstWhere(
                        (e) => e.containerSize == sizes[i],
                        orElse: () => widget.pricebookEntries!.first,
                      );
                      if (entry != null) _loadCharges(entry);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.main : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.main
                                  : Colors.grey.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Radio dot
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.grey,
                                width: 2,
                              ),
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                            ),
                            child:
                                isSelected
                                    ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.main,
                                        ),
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sizes[i],
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF222222),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              // ── Price Breakdown (shown after size is selected) ────────────
              if (selectedSize != null) ...[
                const SizedBox(height: 24),
                _buildPriceBreakdown(),
              ],

              const SizedBox(height: 24),

              // ── Confirm button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      selectedSize != null
                          ? () {
                            final selected = selectedLoadType;
                            Navigator.of(context).pop();
                            widget.onConfirm?.call(selected);
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2251C7),
                    disabledBackgroundColor: const Color(0xFFB5C6E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _oceanFreightPrice(PricebookEntryModel? entry) {
    if (_charges.isNotEmpty) {
      for (final row in _charges) {
        if (row.name.toUpperCase().contains('OCEAN FREIGHT')) {
          return row.sellPrice;
        }
      }
    }
    if (entry != null) {
      return PricingCalculator.calculate(
        entry: entry,
        userType: widget.userType,
        accountMarginPct: widget.accountMarginPct,
        forceMargin: entry.isMarginProduct,
      ).sellPrice;
    }
    return widget.unitPrice;
  }

  // ─── Price Breakdown section ──────────────────────────────────────────────

  Widget _buildPriceBreakdown() {
    final entry = _selectedEntry;
    final sizeLabel =
        entry != null && entry.containerSize.isNotEmpty
            ? '${entry.containerSize} FCL'
            : sizes[selectedSize!];
    final oceanFreightPrice = _oceanFreightPrice(entry);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Price Breakdown',
              style: TextStyle(
                color: AppColors.main,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),

          // Toggle accordion button
          InkWell(
            onTap: () => setState(() => _accordionOpen = !_accordionOpen),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _accordionOpen ? 0 : -0.25,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _accordionOpen
                        ? 'Hide Charges Breakdown'
                        : 'Show Charges Breakdown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF222222),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Charges table (collapsible)
          if (_accordionOpen) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  _chargesLoading
                      ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.main,
                            ),
                          ),
                        ),
                      )
                      : Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Charge Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table rows
                          ..._charges.asMap().entries.map((e) {
                            final isLast = e.key == _charges.length - 1;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                      isLast
                                          ? BorderSide.none
                                          : const BorderSide(
                                            color: Color(0xFFEEEEEE),
                                          ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.value.name,
                                      style: const TextStyle(
                                        color: AppColors.main,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${e.value.currency} ${e.value.sellPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
            ),
            const SizedBox(height: 8),
          ],

          // Footer: container size + ocean freight only
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F7),
              border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const Text(
                      'Ocean Freight',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${oceanFreightPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.main,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portIcon() => Container(
    decoration: BoxDecoration(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(6),
    ),
    padding: const EdgeInsets.all(4),
    child: const Icon(Icons.location_on, color: AppColors.main, size: 16),
  );
}
