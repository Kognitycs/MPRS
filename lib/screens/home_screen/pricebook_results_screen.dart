import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/port_model.dart';
import 'package:mprs_android/screens/quote/price_calculation.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/screens/home_screen/container_size_selection_screen.dart';

import 'package:mprs_android/screens/quote/get_quote_screen.dart';
import 'package:mprs_android/widget/pricebook_entry_card_details.dart';

class PricebookResultsScreen extends StatefulWidget {
  final List<PricebookEntryModel> entries;

  /// Every record returned by pricebook/for/ports (OCEAN FREIGHT + THC +
  /// DO FEE + AGENT DG HANDLING CHARGES …) — used for the price breakdown
  /// inside ContainerSizeSelectionScreen so no second API call is needed.
  final List<PricebookEntryModel> allRecords;

  final List<PortModel> allPorts;
  final List<String> sectorNames;
  final String? initialOriginSector;
  final String? initialOriginPort;
  final String? initialDestinationSector;
  final String? initialDestinationPort;
  final String? opportunityId;
  final String? initialShipmentMode;
  final String? initialContainerType;
  final String? initialContainerSize;
  final String? initialContainerQuantity;
  final String? weightPerContainer;
  final String? cargoValue;
  final String? commodity;
  final String? validFrom;
  final String? validTill;

  const PricebookResultsScreen({
    super.key,
    required this.entries,
    this.allRecords = const [],
    required this.allPorts,
    required this.sectorNames,
    this.initialOriginSector,
    this.initialOriginPort,
    this.initialDestinationSector,
    this.initialDestinationPort,
    this.opportunityId,
    this.initialShipmentMode,
    this.initialContainerType,
    this.initialContainerSize,
    this.initialContainerQuantity,
    this.weightPerContainer,
    this.cargoValue,
    this.commodity,
    this.validFrom,
    this.validTill,
  });

  @override
  State<PricebookResultsScreen> createState() => _PricebookResultsScreenState();
}

class _PricebookResultsScreenState extends State<PricebookResultsScreen> {
  String? selectedOriginPort;
  String? selectedDestinationPort;
  late List<PricebookEntryModel> displayed;
  late List<PortModel> allPorts;

  // null = not configured on account; loading tracked separately.
  double? _accountMarginPct;
  bool _accountMarginLoading = true;

  @override
  void initState() {
    super.initState();
    allPorts = widget.allPorts;
    selectedOriginPort = widget.initialOriginPort;
    selectedDestinationPort = widget.initialDestinationPort;
    displayed = _applyFilters(widget.entries);
    _fetchAccountMargin();
  }

  // ─── filtering ────────────────────────────────────────────────────────────

  List<PricebookEntryModel> _applyFilters(List<PricebookEntryModel> source) {
    return source
        .where(
          (e) =>
              e.matchesOriginSelection(selectedOriginPort) &&
              e.matchesDestinationSelection(selectedDestinationPort),
        )
        .toList()
      ..sort((a, b) => a.mloCode.compareTo(b.mloCode));
  }

  String _displayOriginLabel(PricebookEntryModel entry) {
    if (selectedOriginPort?.trim().isNotEmpty == true &&
        entry.matchesOriginSelection(selectedOriginPort)) {
      return selectedOriginPort!.trim();
    }
    if (entry.originPortName.isNotEmpty) return entry.originPortName;
    if (entry.originIcdName.isNotEmpty) return entry.originIcdName;
    return entry.originName.isNotEmpty ? entry.originName : entry.originCode;
  }

  String _displayDestinationLabel(PricebookEntryModel entry) {
    if (selectedDestinationPort?.trim().isNotEmpty == true &&
        entry.matchesDestinationSelection(selectedDestinationPort)) {
      return selectedDestinationPort!.trim();
    }
    if (entry.destinationPortName.isNotEmpty) {
      return entry.destinationPortName;
    }
    if (entry.destinationIcdName.isNotEmpty) return entry.destinationIcdName;
    return entry.destinationName.isNotEmpty
        ? entry.destinationName
        : entry.destinationCode;
  }

  // ─── grouping (mirrors parsePriceBookEntryDataBasedOnSelection in SF) ─────

  /// Returns an ordered map: mloCode → list of entries for that MLO.
  /// Order is preserved from the sorted `displayed` list.
  LinkedHashMap<String, List<PricebookEntryModel>> get _groupedByMlo {
    final map = LinkedHashMap<String, List<PricebookEntryModel>>();
    for (final e in displayed) {
      map.putIfAbsent(e.mloCode, () => []).add(e);
    }
    return map;
  }

  // ─── account margin fetch ─────────────────────────────────────────────────

  Future<void> _fetchAccountMargin() async {
    try {
      final token = AuthDataHelper.getToken();
      final accountId = AuthDataHelper.getAccountId();
      final url = ApiConstants.userMarginAccount(accountId);
      debugPrint('🔑 Fetching account margin: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders({'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        double? pct;
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          debugPrint('🔑 Account margin raw response: $decoded');

          // The API may nest data under a "data" key (object or first element of list)
          final data =
              (decoded is Map && decoded['data'] is Map)
                  ? decoded['data'] as Map
                  : (decoded is Map &&
                      decoded['data'] is List &&
                      (decoded['data'] as List).isNotEmpty)
                  ? (decoded['data'] as List).first as Map
                  : decoded is Map
                  ? decoded
                  : <String, dynamic>{};

          debugPrint('🔑 Account margin extracted object: $data');

          // Salesforce SOQL returns {totalSize, done, records:[{Account_Margin__c, ...}]}
          // First look inside records[0], then fall back to top-level keys.
          final Map<dynamic, dynamic> record =
              (data['records'] is List && (data['records'] as List).isNotEmpty)
                  ? (data['records'] as List).first as Map
                  : data;

          final raw =
              record['Account_Margin__c'] ??
              record['Account_Margin'] ??
              record['Margin__c'] ??
              record['margin'] ??
              record['accountMargin'] ??
              record['account_margin'] ??
              record['value'];

          if (raw != null) {
            pct = double.tryParse(raw.toString());
          }
          debugPrint('🔑 Parsed accountMarginPct: $pct%');
        } else {
          debugPrint(
            '🔑 Account margin API error: ${response.statusCode} ${response.body}',
          );
        }
        setState(() {
          _accountMarginPct = pct;
          _accountMarginLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔑 Account margin fetch exception: $e');
      if (mounted) {
        setState(() {
          _accountMarginPct = null;
          _accountMarginLoading = false;
        });
      }
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groups = _groupedByMlo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Rates',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.main,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Results (${groups.length} MLO${groups.length == 1 ? '' : 's'})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final mloCode = groups.keys.elementAt(i);
                final entries = groups[mloCode]!;
                return _buildMloCard(context, mloCode, entries);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── MLO card (one card per MLO, all container-size chips inside) ─────────

  Widget _buildMloCard(
    BuildContext context,
    String mloCode,
    List<PricebookEntryModel> entries,
  ) {
    // Sort within the MLO group: 20' always left, 40' always right
    final sorted = [...entries]..sort((a, b) {
      final aIs20 = a.containerSize.contains('20');
      final bIs20 = b.containerSize.contains('20');
      if (aIs20 && !bIs20) return -1;
      if (!aIs20 && bIs20) return 1;
      return a.containerSize.compareTo(b.containerSize);
    });
    final first = sorted.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Route header: Origin ──── Destination ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.anchor, color: AppColors.main, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _displayOriginLabel(first),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 40, height: 2, color: Colors.grey[300]),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.directions_boat_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
                Container(width: 40, height: 2, color: Colors.grey[300]),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _displayDestinationLabel(first),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.location_on,
                        color: AppColors.main,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          PricebookEntryCardDetails(entry: first),

          const Divider(height: 1, thickness: 0.5, indent: 12, endIndent: 12),

          // ── Price chips: one per container-size entry ───────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child:
                _accountMarginLoading
                    // Loading skeleton
                    ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 20' — always left
                        if (sorted.isNotEmpty) _buildPriceChip(sorted[0]),
                        const Spacer(),
                        // 40' — always right
                        if (sorted.length > 1) _buildPriceChip(sorted[1]),
                        // 3+ sizes: append after the right chip
                        if (sorted.length > 2)
                          ...sorted
                              .skip(2)
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _buildPriceChip(e),
                                ),
                              ),
                      ],
                    ),
          ),

          const Divider(height: 1, thickness: 0.5, indent: 12, endIndent: 12),

          // ── Footer: MLO code + PROCEED button ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'MLO Code - ${mloCode.isNotEmpty ? mloCode : 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _onProceed(context, sorted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Price chip (matches Salesforce result-card chip style) ───────────────

  Widget _buildPriceChip(PricebookEntryModel e) {
    final userType = AuthDataHelper.getUserType();

    // Pricing rules apply to OCEAN FREIGHT and THC only (isMarginProduct).
    // For all other products: sell price = unit price.
    final result = PricingCalculator.calculate(
      entry: e,
      userType: userType,
      accountMarginPct: _accountMarginPct,
      forceMargin: true,
    );

    debugPrint(
      '🧮 Chip [${e.mloCode}/${e.containerSize}] '
      'product="${e.productName}" isMargin=${e.isMarginProduct} '
      'sm=${e.suggestedMarginC} override=${e.overrideAccountMarginC} '
      'am%=${_accountMarginPct} '
      '→ sell=${result.sellPrice}',
    );

    final currency =
        e.mprsCurrencyC?.isNotEmpty == true ? e.mprsCurrencyC! : 'USD';
    final sizeLabel = e.containerSize.isNotEmpty ? e.containerSize : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sell price only — no "Buy" / "Sell" labels
          Text(
            '$currency ${result.sellPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.main,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          // Container size
          Text(
            '$sizeLabel FCL',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROCEED: open container-size selection with all sizes for this MLO ───

  void _onProceed(BuildContext context, List<PricebookEntryModel> entries) {
    final first = entries.first;
    final mloCode = first.mloCode;

    // ALL records (OCEAN FREIGHT + THC + DO FEE + etc.) for this MLO.
    // These are already in memory — no second API call needed for breakdown.
    final allForMlo =
        widget.allRecords.where((e) => e.mloCode == mloCode).toList();

    // Sizes come from OCEAN FREIGHT entries (already deduplicated)
    final uniqueSizes =
        entries
            .map((e) => e.containerSize)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

    final pol = _displayOriginLabel(first);
    final pod = _displayDestinationLabel(first);

    debugPrint(
      '💰 [ViewDetails] mlo=${first.mloCode} '
      'userType="${AuthDataHelper.getUserType()}" '
      'accountMarginPct=${_accountMarginPct}% '
      'allForMlo=${allForMlo.length} entries=${entries.length}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => ContainerSizeSelectionScreen(
            origin: pol,
            destination: pod,
            routing: PricebookEntryCardDetails.routingLabel(first),
            transitTime: PricebookEntryCardDetails.transitLabel(first),
            unitPrice: first.unitPrice,
            availableSizes: uniqueSizes,
            // Pass ALL charge records for this MLO → breakdown filters locally
            pricebookEntries: allForMlo.isNotEmpty ? allForMlo : entries,
            containerType:
                first.containerType.isNotEmpty
                    ? first.containerType
                    : widget.initialContainerType,
            numberOfContainers: int.tryParse(
              widget.initialContainerQuantity ?? '',
            ),
            netWeightPerContainer: double.tryParse(
              widget.weightPerContainer ?? '',
            ),
            // Pricing context — margin is loaded before the user can tap the button
            userType: AuthDataHelper.getUserType(),
            accountMarginPct: _accountMarginPct,
            onConfirm: (selectedContainerString) {
              // Find the entry matching the selected container size
              final matched = entries.firstWhere(
                (e) =>
                    selectedContainerString?.contains(e.containerSize) == true,
                orElse: () => first,
              );

              final mappedLoadType =
                  (widget.initialShipmentMode ?? 'Ocean').toLowerCase() == 'air'
                      ? 'AIR'
                      : 'FCL';
              final originPort = allPorts.firstWhere(
                (p) => p.name == pol,
                orElse: () => PortModel(),
              );
              final destPort = allPorts.firstWhere(
                (p) => p.name == pod,
                orElse: () => PortModel(),
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => GetQuoteScreen(
                        selectedMloCode: matched.mloCode,
                        initialPol: pol,
                        initialPod: pod,
                        initialPolId: originPort.portId,
                        initialPodId: destPort.portId,
                        initialLoadType: mappedLoadType,
                        initialShipmentMode: widget.initialShipmentMode,
                        initialContainerType: matched.containerType,
                        initialContainerSize: matched.containerSize,
                        initialContainerQuantity:
                            widget.initialContainerQuantity,
                        initialWeightPerContainer: widget.weightPerContainer,
                        initialGoodsValue: widget.cargoValue,
                        opportunityId: widget.opportunityId,
                        pricebookEntries:
                            allForMlo.isNotEmpty ? allForMlo : entries,
                        initialAccountMarginPct: _accountMarginPct,
                        initialCommodity: widget.commodity,
                        initialValidFrom: widget.validFrom,
                        initialValidTill: widget.validTill,
                      ),
                ),
              );
            },
          ),
    );
  }
}
