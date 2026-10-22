import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart'; // ← NEW (line items)
import 'package:mprs_android/screens/quote/price_calculation.dart';
import 'package:mprs_android/core/utils/url_launcher_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/service/most_used_ports_service.dart';

import '../../controller/search_routes_controller.dart';
import '../../controller/saved_quotations_controller.dart';
import '../../model/icd_model.dart';
import '../main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper model to hold a computed line item before sending
// ─────────────────────────────────────────────────────────────────────────────
class _QuoteLineItem {
  final String product2Id;
  final String pricebookEntryId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double listPrice;
  final double finalSellingPrice;
  final double finalBuyingPrice;
  final String chargeType; // "Origin Charges" | "Destination Charges" etc.
  final String currency;

  const _QuoteLineItem({
    required this.product2Id,
    required this.pricebookEntryId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.listPrice,
    required this.finalSellingPrice,
    required this.finalBuyingPrice,
    required this.chargeType,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
    'Product2Id': product2Id,
    'PricebookEntryId': pricebookEntryId,
    'Product': productName,
    'Quantity': quantity,
    'UnitPrice': unitPrice.round(),
    'ListPrice': listPrice.round(),
    'finalSellingPrice': finalSellingPrice.round(),
    'finalBuyingPrice': finalBuyingPrice.round(),
    'chargeType': chargeType,
    'currency': currency,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// GetQuoteScreen
// ─────────────────────────────────────────────────────────────────────────────
class GetQuoteScreen extends StatefulWidget {
  final String? initialPol;
  final String? initialPod;
  final String? initialLoadType;
  final String? opportunityId;
  final String? initialPolId;
  final String? initialPodId;
  final String? initialContainerType;
  final String? initialContainerSize;
  final String? initialShipmentMode;
  final String? initialContainerQuantity;
  final String? initialCommodity;
  final String? initialValidFrom;
  final String? initialValidTill;
  final String? initialWeightPerContainer;
  final String? initialGoodsValue;

  /// NEW – pricebook entries from the search result so we can compute
  /// line items without an extra network call.
  final List<PricebookEntryModel>? pricebookEntries;

  /// MLO code selected on the previous screen (if any)
  final String? selectedMloCode;

  /// Account margin % already fetched on pricebook screen (optional).
  final double? initialAccountMarginPct;

  const GetQuoteScreen({
    Key? key,
    this.initialPol,
    this.initialPod,
    this.initialLoadType,
    this.opportunityId,
    this.initialPolId,
    this.initialPodId,
    this.initialContainerType,
    this.initialContainerSize,
    this.initialShipmentMode,
    this.initialContainerQuantity,
    this.initialCommodity,
    this.initialValidFrom,
    this.initialValidTill,
    this.initialWeightPerContainer,
    this.initialGoodsValue,
    this.pricebookEntries,
    this.selectedMloCode,
    this.initialAccountMarginPct,
  }) : super(key: key);

  @override
  State<GetQuoteScreen> createState() => _GetQuoteScreenState();
}

class _GetQuoteScreenState extends State<GetQuoteScreen> {
  static const _masterTermsUrl =
      'https://mprsshipping.com/master-terms-conditions/';
  final _formKey = GlobalKey<FormState>();
  double? accountMarginPct;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final companyController = TextEditingController();
  final gstinController = TextEditingController();
  final opportunityIdController = TextEditingController();
  final polController = TextEditingController();
  final podController = TextEditingController();
  final leadSourceController = TextEditingController();
  final pickUpAddressController = TextEditingController();
  final deliveryAddressController = TextEditingController();
  final numberOfContainersController = TextEditingController();
  final weightPerContainerController = TextEditingController();
  final grossWeightController = TextEditingController();
  final goodsValueController = TextEditingController();
  final validFromController = TextEditingController();
  final validTillController = TextEditingController();
  final additionalInfoController = TextEditingController();
  bool isPersonalInfoExpanded = false;
  // ── State ─────────────────────────────────────────────────────────────────
  String? selectedLoadType;
  String? selectedContainerType;
  String? selectedContainerSize;
  String? selectedShipmentMode;
  bool acceptedTerms = false;
  bool _isSubmitting = false;
  String? polId;
  String? podId;
  List<IcdModel> icdList = [];
  bool isLoadingIcd = false;
  String? selectedReceiptId;
  String? selectedDestinationId;

  final shipmentModeController = TextEditingController(text: 'Ocean');

  // ── Options ───────────────────────────────────────────────────────────────
  final List<String> containerTypes = [
    'Standard(Dry Container)',
    'Open Top',
    'Flat Rack',
    'ISO Tank - Haz',
    'Haz',
  ];

  final Map<String, List<String>> _containerSizeMap = {
    'Flat Rack': [
      '20 FLAT',
      '40 FLAT STANDARD',
      '40 FLAT HIGH',
      "20'FLAT RACK (IN-GUAGE)",
      "40'FLAT RACK (IN-GUAGE)",
      "20'FLAT RACK (OUT-GUAGE)",
      "40'FLAT RACK (OUT-GUAGE)",
    ],
    'Open Top': [
      '20 OPEN TOP (IN- GUAGE)',
      '40 OPEN TOP (IN-GUAGE)',
      "40'HIGH CUBE OPEN TOP (IN-GUAGE)",
      '40 OPEN TOP HIGH (OUT-GUAGE)',
      '20 OPEN TOP (OUT-GUAGE)',
    ],
    'Haz': ["20'HD Haz", "40'HC Haz", "45'HC Haz", "20 REEFER HAZ"],
    'ISO Tank - Haz': [
      '20 TANK HAZ',
      '40 TANK HAZ',
      '20 TANK (SOC) HAZ',
      '40 TANK (SOC) HAZ',
    ],
    '__default__': [
      "20'",
      "40'HC",
      "45'HC",
      "40GP",
      "20 TANK",
      "40 TANK",
      "20 TANK (SOC)",
      "40 TANK (SOC)",
      "20 SOC",
      "40 HQ SOC",
    ],
  };

  List<String> get _currentSizes =>
      _containerSizeMap[selectedContainerType] ??
      _containerSizeMap['__default__']!;

  List<String> get _loadTypes => ['FCL', 'LCL'];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    accountMarginPct = widget.initialAccountMarginPct;
    debugPrint(
      "RECEIVED ENTRIES : "
      "${widget.pricebookEntries?.length}",
    );
    fetchIcdLocations();

    getAccountMargin();

    _initDropdowns();

    _loadUserData();
  }

  bool get _showAddressFields =>
      selectedReceiptId != null || selectedDestinationId != null;
  Future<void> getAccountMargin() async {
    try {
      final token = AuthDataHelper.getToken();

      final accountId = AuthDataHelper.getAccountId();

      final response = await http.get(
        Uri.parse(ApiConstants.userMarginAccount(accountId)),

        headers: AppConfig.mergeApiHeaders({'Authorization': 'Bearer $token'}),
      );

      debugPrint("MARGIN RESPONSE : ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
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

        final record =
            (data['records'] is List && (data['records'] as List).isNotEmpty)
                ? (data['records'] as List).first as Map
                : data;

        final raw =
            record['Account_Margin__c'] ??
            record['Account_Margin'] ??
            record['margin'];

        setState(() {
          accountMarginPct =
              raw == null ? null : double.tryParse(raw.toString());
        });

        debugPrint("ACCOUNT MARGIN : $accountMarginPct");
      }
    } catch (e) {
      debugPrint("MARGIN ERROR : $e");
    }
  }

  void _initDropdowns() {
    selectedShipmentMode = 'Ocean';
    shipmentModeController.text = 'Ocean';
    final avail = _loadTypes;
    selectedLoadType =
        (widget.initialLoadType != null &&
                avail.contains(widget.initialLoadType))
            ? widget.initialLoadType
            : null;

    String? mappedType = widget.initialContainerType;
    if (mappedType == 'FCL' || mappedType == 'LCL') {
      mappedType = 'Standard(Dry Container)';
    }
    if (mappedType == 'Standard') mappedType = 'Standard(Dry Container)';
    if (mappedType == 'OpenTop') mappedType = 'Open Top';
    selectedContainerType =
        containerTypes.contains(mappedType) ? mappedType : null;

    String normalize(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll('\u2019', "'")
        .replaceAll('\u2018', "'")
        .replaceAll(RegExp(r'\s+'), ' ');

    final sizes =
        _containerSizeMap[mappedType] ?? _containerSizeMap['__default__']!;
    final incoming = widget.initialContainerSize ?? '';
    selectedContainerSize =
        sizes.any((e) => normalize(e) == normalize(incoming))
            ? sizes.firstWhere((e) => normalize(e) == normalize(incoming))
            : null;

    numberOfContainersController.text = widget.initialContainerQuantity ?? '1';
    polId = widget.initialPolId;
    podId = widget.initialPodId;
  }

  void _loadUserData() {
    final first = AuthDataHelper.getFirstName();
    final last = AuthDataHelper.getLastName();
    nameController.text = '$first $last'.trim();
    emailController.text = AuthDataHelper.getEmail();
    phoneController.text = AuthDataHelper.getMobile();
    companyController.text = AuthDataHelper.getCompanyName();
    gstinController.text = AuthDataHelper.getGstin();

    String? oppId = widget.opportunityId?.trim();
    String? validTill = widget.initialValidTill?.trim();
    if (Get.isRegistered<SearchRouteController>()) {
      final searchCtrl = Get.find<SearchRouteController>();
      oppId ??= searchCtrl.lastOpportunityId?.trim();
      validTill ??= searchCtrl.lastValidTill?.trim();
    }
    opportunityIdController.text = oppId ?? '';

    if (widget.initialPol?.isNotEmpty == true) {
      polController.text = widget.initialPol!;
    }
    if (widget.initialPod?.isNotEmpty == true) {
      podController.text = widget.initialPod!;
    }
    if (widget.initialCommodity?.isNotEmpty == true) {
      additionalInfoController.text = widget.initialCommodity!;
    }
    if (widget.initialValidFrom?.isNotEmpty == true) {
      validFromController.text = widget.initialValidFrom!;
    }
    if (validTill != null && validTill.isNotEmpty) {
      validTillController.text = validTill;
    }
    if (widget.initialWeightPerContainer?.isNotEmpty == true) {
      final netWt = widget.initialWeightPerContainer!.trim();
      weightPerContainerController.text = netWt;
      grossWeightController.text = netWt;
    }
    if (widget.initialGoodsValue?.isNotEmpty == true) {
      goodsValueController.text = widget.initialGoodsValue!;
    }
  }

  String? get _resolvedOpportunityId {
    final fromWidget = widget.opportunityId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    final fromController = opportunityIdController.text.trim();
    if (fromController.isNotEmpty) return fromController;

    if (Get.isRegistered<SearchRouteController>()) {
      final cached =
          Get.find<SearchRouteController>().lastOpportunityId?.trim();
      if (cached != null && cached.isNotEmpty) return cached;
    }
    return null;
  }

  String _formatQuoteDate(String rawDate) {
    final parts = rawDate.split('-');
    if (parts.length != 3) return rawDate;
    return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
  }

  Future<String?> _ensureOpportunityId() async {
    final existing = _resolvedOpportunityId;
    if (existing != null && existing.isNotEmpty) return existing;

    if (!Get.isRegistered<SearchRouteController>()) return null;
    final searchCtrl = Get.find<SearchRouteController>();

    try {
      final resp = await searchCtrl.createOpportunityApi();
      if (resp.statusCode != 200 && resp.statusCode != 201) return null;

      final body = jsonDecode(resp.data);
      if (body is! Map || body['success'] != true) return null;

      final id = SearchRouteController.parseOpportunityIdFromBody(body);
      final till = SearchRouteController.parseValidTillFromBody(body);
      searchCtrl.lastOpportunityId = id;
      searchCtrl.lastValidTill = till;

      if (id != null) {
        opportunityIdController.text = id;
      }
      if (till != null && validTillController.text.trim().isEmpty) {
        validTillController.text = till;
      }
      return id;
    } catch (e) {
      debugPrint('Ensure opportunity error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    for (final c in [
      nameController,
      emailController,
      phoneController,
      companyController,
      gstinController,
      opportunityIdController,
      polController,
      podController,
      leadSourceController,
      pickUpAddressController,
      deliveryAddressController,
      numberOfContainersController,
      weightPerContainerController,
      grossWeightController,
      goodsValueController,
      validFromController,
      validTillController,
      additionalInfoController,
      shipmentModeController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<_QuoteLineItem> _buildLineItems() {
    final allEntries = widget.pricebookEntries ?? [];

    debugPrint("TOTAL ENTRIES : ${allEntries.length}");

    if (allEntries.isEmpty) {
      debugPrint("NO PRICEBOOK ENTRIES");
      return [];
    }

    String normalize(dynamic value) {
      return value
          .toString()
          .toLowerCase()
          .replaceAll(" ", "")
          .replaceAll("\\", "")
          .replaceAll("’", "'")
          .replaceAll('"', "")
          .trim();
    }

    // Prefer the dropdown selection; fall back to the size passed from the pricebook
    // so we never accidentally include all entries when the dropdown value is null.
    final rawSelected =
        (selectedContainerSize?.isNotEmpty == true
                ? selectedContainerSize!
                : widget.initialContainerSize ?? '')
            .trim();
    final selectedSize = rawSelected.isEmpty ? '' : normalize(rawSelected);

    debugPrint("SELECTED SIZE NORMALIZED : $selectedSize");

    final entries =
        allEntries.where((e) {
          // Never auto-include THC — it must be explicitly selected
          if (e.productName.toLowerCase().contains('thc')) return false;

          // No size selected — include everything
          if (selectedSize.isEmpty) return true;

          final apiSize = normalize(e.containerSize);

          // Always include entries with no container size (e.g. handling charges)
          if (apiSize.isEmpty) return true;

          final sizeMatch =
              apiSize.contains(selectedSize) || selectedSize.contains(apiSize);

          debugPrint(
            "ENTRY => size=${e.containerSize} apiSize=$apiSize sizeMatch=$sizeMatch",
          );

          return sizeMatch;
        }).toList();

    debugPrint("FILTERED ENTRIES : ${entries.length}");

    if (entries.isEmpty) {
      debugPrint("NO MATCHED ENTRIES FOUND");

      return [];
    }

    final oceanRows =
        entries
            .where((e) => e.productName.toUpperCase().contains('OCEAN FREIGHT'))
            .toList();
    final otherRows =
        entries
            .where(
              (e) => !e.productName.toUpperCase().contains('OCEAN FREIGHT'),
            )
            .toList()
          ..sort((a, b) => a.productName.compareTo(b.productName));

    final sortedEntries = [...oceanRows, ...otherRows];
    final userType = AuthDataHelper.getUserType();

    final qty = int.tryParse(numberOfContainersController.text) ?? 1;
    return sortedEntries.map((entry) {
      final result = PricingCalculator.calculate(
        entry: entry,
        userType: userType,
        accountMarginPct: accountMarginPct,
        forceMargin: entry.isMarginProduct,
      );

      final buy = result.buyPrice;
      final sell = result.sellPrice;
      // Salesforce totals use UnitPrice × Quantity — margin products must
      // send the calculated sell price as UnitPrice so the line total is correct.
      final apiUnitPrice = entry.isMarginProduct ? sell : buy;

      debugPrint(
        '📦 LineItem "${entry.productName}" | '
        'size=${entry.containerSize} | '
        'isMargin=${entry.isMarginProduct} | '
        'buy=$buy | sell=$sell | '
        'UnitPrice(sent)=$apiUnitPrice | total=${apiUnitPrice * qty}',
      );

      return _QuoteLineItem(
        product2Id: entry.product2Id ?? '',
        pricebookEntryId: entry.id,
        productName: entry.productName,
        quantity: qty,
        unitPrice: apiUnitPrice,
        listPrice: apiUnitPrice,
        finalSellingPrice: sell,
        finalBuyingPrice: buy,
        chargeType: _resolveChargeType(entry),
        currency: entry.mprsCurrencyC ?? 'USD',
      );
    }).toList();
  }

  String _resolveChargeType(PricebookEntryModel entry) {
    return 'Origin Charges';
  }

  /// User-entered goods value, or null when the optional field is left empty.
  int? _parsedGoodsValue() {
    final text = goodsValueController.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return value.round();
  }

  /// API `/user/create/quote` requires `goodsValue` as a positive number (Joi).
  /// When the user skips the optional field, send a minimal placeholder so booking succeeds.
  num _goodsValueForApi() {
    final parsed = _parsedGoodsValue();
    if (parsed != null && parsed > 0) return parsed;
    return 0.01;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (!acceptedTerms) {
      _snack('Please accept the terms and conditions', Colors.red);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      var opportunityId = _resolvedOpportunityId;
      if (opportunityId == null || opportunityId.isEmpty) {
        opportunityId = await _ensureOpportunityId();
      }
      if (opportunityId == null || opportunityId.isEmpty) {
        _snack('Opportunity ID missing', Colors.red);
        return;
      }
      if (validFromController.text.isEmpty ||
          additionalInfoController.text.isEmpty) {
        _snack('Please fill all required fields', Colors.red);
        return;
      }

      final token = AuthDataHelper.getToken();
      final formattedDate = _formatQuoteDate(validFromController.text);
      final formattedValidTill =
          validTillController.text.trim().isEmpty
              ? null
              : _formatQuoteDate(validTillController.text.trim());
      final netWeight =
          (double.tryParse(weightPerContainerController.text) ?? 0).round();
      final grossWeight = netWeight;
      //Arnima - make not editable fields date and send the data from those fields in payload instead of user input
      final lineItems = _buildLineItems();
      debugPrint('📦 Line items count: ${lineItems.length}');
      final goodsValue = _goodsValueForApi();

      final pricebook2Id = (widget.pricebookEntries ?? [])
          .map((e) => e.pricebook2Id)
          .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);

      //quotename inprogress
      //opprtunityid remove in getquote

      // ── Build quote payload ───────────────────────────────────────────
      final ts = DateTime.now().millisecondsSinceEpoch % 100000;
      final quoteName = 'QT-${ts.toString().padLeft(5, '0')}';

      final quotePayload = {
        'quote': {
          'name': quoteName,
          'opportunityId': opportunityId,
          if (pricebook2Id != null) 'Pricebook2Id': pricebook2Id,
          if (formattedValidTill != null) 'validTill': formattedValidTill,
          if (formattedValidTill != null) 'valid_till_c': formattedValidTill,
          'loadType': selectedLoadType == 'AIR' ? 'Air' : selectedLoadType,
          if (selectedReceiptId != null) 'placeOfReceipt': selectedReceiptId,
          if (selectedDestinationId != null)
            'finalPlaceOfDestination': selectedDestinationId,
          if (pickUpAddressController.text.trim().isNotEmpty)
            'pickUpAddress': pickUpAddressController.text.trim(),
          if (deliveryAddressController.text.trim().isNotEmpty)
            'deliveryAddress': deliveryAddressController.text.trim(),
          'portOfLoading': polId,
          'portOfDischarge': podId,
          'weightPerContainer': netWeight,
          'goodsValue': goodsValue,
          'additionalInfo': additionalInfoController.text,
          'grossWeight': grossWeight,
          'validFrom': formattedDate,
        },
        'quoteLineItems': lineItems.map((li) => li.toJson()).toList(),
      };

      debugPrint('📤 FINAL QUOTE PAYLOAD:\n${jsonEncode(quotePayload)}');
      log('📤 FINAL QUOTE PAYLOAD:\n${jsonEncode(quotePayload)}');

      final response = await http.post(
        Uri.parse(ApiConstants.createQuote),
        headers: AppConfig.mergeApiHeaders({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
        body: jsonEncode(quotePayload),
      );

      debugPrint('📥 STATUS: ${response.statusCode}');
      log('📥 Quote response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await MostUsedPortsService.recordPortUsage(
          portOfLoading: polController.text.trim(),
          portOfDischarge: podController.text.trim(),
        );
        _snack('✅ Quote submitted successfully!', Colors.green);
        if (Get.isRegistered<SavedQuotationsController>()) {
          await Get.find<SavedQuotationsController>().fetchSavedQuotes();
        }
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder:
                  (_) => const MainScreen(
                    initialTab: 2,
                    initialBookTab: 1,
                    initialBookQuoteFilter: 1,
                  ),
            ),
            (route) => false,
          );
        }
      } else {
        _logQuoteSubmitFailure(response.statusCode, response.body);
        _showServiceError();
      }
    } catch (e, stack) {
      log('❌ Quote submit error: $e\n$stack');
      _showServiceError();
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openMasterTerms() async {
    final opened = await openHttpUrl(_masterTermsUrl);
    if (!opened && mounted) {
      _snack('Could not open terms page', Colors.red);
    }
  }

  Widget _buildTermsAcceptanceLabel({TextStyle? style}) {
    final baseStyle =
        style ??
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('I accept the ', style: baseStyle),
        GestureDetector(
          onTap: _openMasterTerms,
          child: Text(
            'Master Terms & Conditions',
            style: baseStyle.copyWith(
              color: AppColors.main,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(' of Quotation, Booking & Tendering Services', style: baseStyle),
      ],
    );
  }

  void _logQuoteSubmitFailure(int statusCode, String body) {
    log('❌ Quote submit failed. HTTP $statusCode');
    log('❌ Quote error body: $body');
    try {
      final errorData = jsonDecode(body);
      if (errorData is Map) {
        final message = errorData['message']?.toString().trim();
        final status = errorData['status'];
        log(
          '❌ Quote server error: status=$status message=${message ?? '(none)'}',
        );
      }
    } catch (e) {
      log('❌ Quote error body was not JSON: $e');
    }
  }

  void _showServiceError() {
    Get.snackbar(
      'Error',
      AppStrings.serviceNotFound,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: 'Get a Quote',
        onBack: () async {
          try {
            final token = AuthDataHelper.getToken();
            await http.post(
              Uri.parse(ApiConstants.createCaseFromRms),
              headers: AppConfig.mergeApiHeaders({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              }),
              body: jsonEncode({
                'opportunityId': _resolvedOpportunityId,
                'containerType': selectedContainerType,
                'containerSize': selectedContainerSize,
                'commodity':
                    additionalInfoController.text.trim().isEmpty
                        ? 'General Cargo'
                        : additionalInfoController.text.trim(),
                'originPortId': widget.initialPolId,
                'destinationPortId': widget.initialPodId,
              }),
            );
          } catch (e) {
            debugPrint('CASE API ERROR: $e');
          }
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlowSteps(),
              const Text(
                'Request a Quote',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in the details below to get your shipping quote',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              // ── Personal Information ──────────────────────────────────
              // ── Personal Information ──────────────────────────────────
              _sectionCard(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                trailing: IconButton(
                  icon: Icon(
                    isPersonalInfoExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  onPressed: () {
                    setState(() {
                      isPersonalInfoExpanded = !isPersonalInfoExpanded;
                    });
                  },
                ),
                children:
                    isPersonalInfoExpanded
                        ? [
                          _field(
                            nameController,
                            'Full Name',
                            Icons.person_rounded,
                            readOnly: true,
                          ),
                          _field(
                            emailController,
                            'Email Address',
                            Icons.email_rounded,
                            readOnly: true,
                            type: TextInputType.emailAddress,
                          ),
                          _field(
                            phoneController,
                            'Phone Number',
                            Icons.phone_rounded,
                            readOnly: true,
                            type: TextInputType.phone,
                          ),
                          _field(
                            companyController,
                            'Company Name',
                            Icons.business_rounded,
                            readOnly: true,
                          ),
                          _field(
                            gstinController,
                            'GSTIN',
                            Icons.receipt_long_rounded,
                            readOnly: true,
                          ),

                          // REMOVE THIS FIELD FROM UI
                          // _field(
                          //   opportunityIdController,
                          //   'Opportunity ID',
                          //   Icons.tag_rounded,
                          //   readOnly: true,
                          // ),
                        ]
                        : [],
              ),

              const SizedBox(height: 8),

              // ── Shipping Details ──────────────────────────────────────
              _sectionCard(
                title: 'Shipping Details',
                icon: Icons.local_shipping_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _fancyDropdown(
                          label: 'Load Type',
                          icon: Icons.layers_rounded,
                          value:
                              _loadTypes.contains(selectedLoadType)
                                  ? selectedLoadType
                                  : null,
                          items: _loadTypes,
                          isRequired: true,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          shipmentModeController,
                          'Shipment Mode',
                          Icons.directions_boat_rounded,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          polController,
                          'POL',
                          Icons.anchor_rounded,
                          readOnly: true,
                        ),
                      ),

                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          podController,
                          'POD',
                          Icons.anchor_rounded,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          validFromController,
                          'Valid From (YYYY-MM-DD)',
                          Icons.calendar_today_rounded,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          validTillController,
                          'Valid Till (YYYY-MM-DD)',
                          Icons.event_rounded,
                          readOnly: true,
                          hintText: '—',
                        ),
                      ),
                    ],
                  ),
                  if (_showAddressFields) ...[
                    _field(
                      pickUpAddressController,
                      'Pickup Address',
                      Icons.location_city_rounded,
                      readOnly: true,
                      maxLines: 2,
                    ),
                    _field(
                      deliveryAddressController,
                      'Delivery Address',
                      Icons.local_shipping_rounded,
                      readOnly: true,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // ── Container Details ─────────────────────────────────────
              _sectionCard(
                title: 'Container Details',
                icon: Icons.inventory_2_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _fancyDropdown(
                          label: 'Container Type',
                          icon: Icons.view_in_ar_rounded,
                          value: selectedContainerType,
                          items: containerTypes,
                          isRequired: true,
                          readOnly: true,
                          validator: (v) => v == null ? 'Select type' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fancyDropdown(
                          label: 'Container Size',
                          icon: Icons.straighten_rounded,
                          value:
                              _currentSizes.contains(selectedContainerSize)
                                  ? selectedContainerSize
                                  : null,
                          items: _currentSizes,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          numberOfContainersController,
                          'No. of Containers',
                          Icons.numbers_rounded,
                          type: TextInputType.number,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          goodsValueController,
                          'Goods Value (USD)',
                          Icons.attach_money_rounded,
                          type: TextInputType.number,
                          readOnly: true,
                          hintText: '—',
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          weightPerContainerController,
                          'Net Weight / Container (KGS)',
                          Icons.monitor_weight_rounded,
                          type: TextInputType.number,
                          readOnly: true,
                          hintText: '—',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          grossWeightController,
                          'Gross Weight (KGS)',
                          Icons.scale_rounded,
                          type: TextInputType.number,
                          readOnly: true,
                          hintText: '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Additional Information ────────────────────────────────
              _sectionCard(
                title: 'Additional Information',
                icon: Icons.info_outline_rounded,
                children: [
                  Text(
                    'Commodity Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: additionalInfoController,
                    readOnly: true,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '—',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.all(10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Terms ─────────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      acceptedTerms
                          ? AppColors.main.withOpacity(0.06)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        acceptedTerms ? AppColors.main : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: acceptedTerms,
                        onChanged:
                            (v) => setState(() => acceptedTerms = v ?? false),
                        activeColor: AppColors.main,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Expanded(child: _buildTermsAcceptanceLabel()),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              _SwipeDownloadQuote(
                enabled: acceptedTerms,
                busy: _isSubmitting,
                onConfirmed: _submitForm,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowSteps() {
    const labels = ['Route', 'Rates', 'Review'];
    const current = 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color:
                      i <= current ? AppColors.main : const Color(0xFFD9DEE8),
                ),
              ),
            InkWell(
              onTap:
                  i < current ? () => Navigator.of(context).maybePop() : null,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          i <= current
                              ? AppColors.main
                              : const Color(0xFFE8EDF5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color:
                            i <= current
                                ? Colors.white
                                : const Color(0xFF8A93A6),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i <= current ? FontWeight.w700 : FontWeight.w500,
                      color:
                          i <= current
                              ? AppColors.main
                              : const Color(0xFF8A93A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.main.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.main, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.main,
                  ),
                ),
                const Spacer(),

                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _intersperse(children, const SizedBox(height: 8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────
  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool readOnly = false,
    TextInputType? type,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
    GestureTapCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          // readOnly: onTap != null ? true : readOnly,
          onTap: onTap,
          keyboardType: type,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
              icon,
              color: readOnly ? Colors.grey.shade400 : AppColors.main,
              size: 18,
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF3F4F6) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.main, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Dropdown ──────────────────────────────────────────────────────────────
  Widget _fancyDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    ValueChanged<String?>? onChanged,
    bool readOnly = false,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    final uniqueItems = items.toSet().toList();
    final safeValue =
        (value != null && uniqueItems.contains(value)) ? value : null;
    final isLocked = readOnly || onChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          validator: validator,
          icon: Icon(
            isLocked
                ? Icons.lock_outline_rounded
                : Icons.keyboard_arrow_down_rounded,
            color:
                isLocked
                    ? Colors.grey.shade400
                    : (safeValue != null
                        ? AppColors.main
                        : Colors.grey.shade400),
            size: 22,
          ),
          dropdownColor: Colors.white,
          elevation: 4,
          menuMaxHeight: 280,
          borderRadius: BorderRadius.circular(14),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.grey.shade700 : const Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            hintText: 'Select $label',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                icon,
                color:
                    isLocked
                        ? Colors.grey.shade400
                        : (safeValue != null
                            ? AppColors.main
                            : Colors.grey.shade400),
                size: 15,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor:
                isLocked
                    ? const Color(0xFFF3F4F6)
                    : (safeValue != null
                        ? AppColors.main.withOpacity(0.03)
                        : Colors.white),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    safeValue != null
                        ? AppColors.main.withOpacity(0.4)
                        : Colors.grey.shade200,
                width: safeValue != null ? 1.8 : 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.main, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.8),
            ),
          ),
          selectedItemBuilder:
              (context) =>
                  uniqueItems
                      .map(
                        (e) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            e,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      )
                      .toList(),
          items:
              uniqueItems
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Row(
                        children: [
                          if (e == safeValue)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_rounded,
                                color: AppColors.main,
                                size: 15,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              e,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    e == safeValue
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                color:
                                    e == safeValue
                                        ? AppColors.main
                                        : const Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
          onChanged: isLocked ? null : onChanged,
        ),
      ],
    );
  }

  // ── ICD fetch ─────────────────────────────────────────────────────────────
  Future<void> fetchIcdLocations() async {
    setState(() => isLoadingIcd = true);
    try {
      final token = AuthDataHelper.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.receiptLocation),
        headers: AppConfig.mergeApiHeaders({'Authorization': 'Bearer $token'}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List list = data['data'];
        setState(() {
          icdList = list.map((e) => IcdModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('ICD error: $e');
    } finally {
      setState(() => isLoadingIcd = false);
    }
  }

  List<Widget> _intersperse(List<Widget> children, Widget separator) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) result.add(separator);
    }
    return result;
  }
}

/// Left-to-right swipe. Stays locked until the terms checkbox is on.
class _SwipeDownloadQuote extends StatefulWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onConfirmed;

  const _SwipeDownloadQuote({
    required this.enabled,
    required this.busy,
    required this.onConfirmed,
  });

  @override
  State<_SwipeDownloadQuote> createState() => _SwipeDownloadQuoteState();
}

class _SwipeDownloadQuoteState extends State<_SwipeDownloadQuote>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  late final AnimationController _hint;

  @override
  void initState() {
    super.initState();
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SwipeDownloadQuote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.enabled || (oldWidget.busy && !widget.busy)) && _drag != 0) {
      _drag = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.busy;
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumb = 52.0;
        final max = (constraints.maxWidth - thumb - 8).clamp(
          0.0,
          constraints.maxWidth,
        );
        final offset = widget.enabled ? _drag.clamp(0.0, max) : 0.0;
        final progress = max == 0 ? 0.0 : offset / max;
        final label =
            widget.busy
                ? 'Preparing your quote…'
                : widget.enabled
                ? 'Slide to download quote'
                : 'Accept terms to unlock';

        return AnimatedBuilder(
          animation: _hint,
          builder: (context, _) {
            final nudge = active ? (_hint.value * 8) : 0.0;
            return Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors:
                      widget.enabled
                          ? const [Color(0xFF0039B5), Color(0xFF2F6BFF)]
                          : const [Color(0xFFE7EAF0), Color(0xFFF4F6F8)],
                ),
                boxShadow: [
                  if (widget.enabled)
                    BoxShadow(
                      color: AppColors.main.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: offset + thumb + 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: (1 - progress).clamp(0.25, 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.enabled)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: Color(0xFF98A2B3),
                                ),
                              ),
                            Text(
                              label,
                              style: TextStyle(
                                color:
                                    widget.enabled
                                        ? Colors.white
                                        : const Color(0xFF98A2B3),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (active) ...[
                              const SizedBox(width: 8),
                              Transform.translate(
                                offset: Offset(nudge, 0),
                                child: Icon(
                                  Icons.keyboard_double_arrow_right,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 22,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6 + offset,
                      child: GestureDetector(
                        onHorizontalDragUpdate:
                            active
                                ? (details) {
                                  setState(() {
                                    _drag = (_drag + details.delta.dx).clamp(
                                      0.0,
                                      max,
                                    );
                                  });
                                }
                                : null,
                        onHorizontalDragEnd:
                            active
                                ? (_) {
                                  final done = max > 0 && _drag >= max * 0.82;
                                  setState(() => _drag = done ? max : 0);
                                  if (done) widget.onConfirmed();
                                }
                                : null,
                        child: Container(
                          width: thumb,
                          height: thumb,
                          decoration: BoxDecoration(
                            color:
                                widget.enabled
                                    ? Colors.white
                                    : const Color(0xFFD0D5DD),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              widget.busy
                                  ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppColors.main,
                                    ),
                                  )
                                  : Icon(
                                    widget.enabled
                                        ? Icons.arrow_forward_rounded
                                        : Icons.lock_outline,
                                    color:
                                        widget.enabled
                                            ? AppColors.main
                                            : const Color(0xFF98A2B3),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
