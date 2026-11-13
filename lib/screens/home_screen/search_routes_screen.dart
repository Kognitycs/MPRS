import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/model/pricebook_entry_model.dart';
import 'package:mprs_android/screens/home_screen/container_size_selection_screen.dart';
import 'package:mprs_android/screens/quote/get_quote_screen.dart';
import 'package:mprs_android/screens/quote/price_calculation.dart';
import 'package:mprs_android/widget/pricebook_entry_card_details.dart';
import 'package:mprs_android/widget/searchable_dropdown.dart';
import '../../controller/search_routes_controller.dart';
import '../../model/internal_quote_line_edit.dart';
import '../../model/port_model.dart';
import '../../service/sales_account_directory.dart';

class SearchRouteScreen extends StatefulWidget {
  final bool embedded;

  const SearchRouteScreen({super.key, this.embedded = false});

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  late final SearchRouteController controller;
  int _step = 0;
  String? _originError;
  String? _destinationError;
  List<PricebookEntryModel>? _selectedMloEntries;
  double? _accountMarginPct;
  bool _marginLoading = false;
  List<SalesAccountChoice> _salesAccounts = [];
  bool _salesAccountsLoading = false;
  String? _selectedSalesAccountId;
  String _accountSearchQuery = '';
  final TextEditingController _accountSearchCtrl = TextEditingController();

  bool get _picksAccount =>
      AuthDataHelper.getUserType().toLowerCase().trim() == 'internal';

  int? get _accountStep => _picksAccount ? 0 : null;
  int get _routeStep => _picksAccount ? 1 : 0;
  int get _ratesStep => _picksAccount ? 2 : 1;
  int? get _editPriceStep => _picksAccount ? 3 : null;
  int? get _getQuoteStep => _picksAccount ? 4 : null;
  int get _reviewStep => 2;

  List<InternalQuoteLineEdit>? _lineEdits;
  PricebookEntryModel? _selectedPricebookEntry;
  String? _selectedContainerSize;
  List<PricebookEntryModel>? _quotePricebookEntries;
  final Map<String, TextEditingController> _sellControllers = {};
  final Map<String, TextEditingController> _taxControllers = {};

  static const _pageBg = Colors.white;
  static const _titleColor = Color(0xFF1C2434);
  static const _muted = Color(0xFF8A93A6);
  static const _cardBorder = Color(0xFFE4E7EC);

  @override
  void initState() {
    super.initState();
    controller = Get.put(SearchRouteController());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeForm());
    if (_picksAccount) _loadSalesAccounts();
  }

  Future<void> _loadSalesAccounts() async {
    setState(() => _salesAccountsLoading = true);
    final result = await SalesAccountDirectory.loadForCurrentUser();
    if (!mounted) return;
    setState(() {
      _salesAccounts = result.choices;
      _salesAccountsLoading = false;
      _selectedSalesAccountId = null;
    });
    controller.selectedSalesAccount.value = null;
  }

  List<SalesAccountChoice> get _visibleSalesAccounts {
    final query = _accountSearchQuery.trim().toLowerCase();
    final self = _salesAccounts.where((c) => c.isSelf);
    final assigned = _salesAccounts.where((c) => !c.isSelf);
    if (query.isEmpty) {
      return [...self, ...assigned];
    }
    bool matches(SalesAccountChoice c) => c.name.toLowerCase().contains(query);
    return [...self.where(matches), ...assigned.where(matches)];
  }

  @override
  void dispose() {
    _accountSearchCtrl.dispose();
    _disposeLineControllers();
    super.dispose();
  }

  void _disposeLineControllers() {
    for (final c in _sellControllers.values) {
      c.dispose();
    }
    for (final c in _taxControllers.values) {
      c.dispose();
    }
    _sellControllers.clear();
    _taxControllers.clear();
  }

  void _syncLineEditsFromControllers() {
    if (_lineEdits == null) return;
    for (final line in _lineEdits!) {
      final sellText = _sellControllers[line.pricebookEntryId]?.text.trim();
      final taxText = _taxControllers[line.pricebookEntryId]?.text.trim();
      final sell = double.tryParse(sellText ?? '');
      if (sell != null) line.sellPrice = sell;
      final tax = double.tryParse(taxText ?? '');
      line.taxPercent = tax ?? 0;
    }
  }

  double _parsedSellFromField(InternalQuoteLineEdit line) {
    final text = _sellControllers[line.pricebookEntryId]?.text.trim() ?? '';
    return double.tryParse(text) ?? line.sellPrice;
  }

  bool _lineSellBelowBuy(InternalQuoteLineEdit line) {
    return _parsedSellFromField(line) < line.buyPrice - 0.001;
  }

  bool get _editPriceCanContinue {
    if (!_picksAccount || _editPriceStep == null || _step != _editPriceStep) {
      return true;
    }
    if (_lineEdits == null || _lineEdits!.isEmpty) return false;
    return _lineEdits!.every((line) => !_lineSellBelowBuy(line));
  }

  void _primeLineEditControllers(List<InternalQuoteLineEdit> lines) {
    _disposeLineControllers();
    _lineEdits = lines;
    for (final line in lines) {
      _sellControllers[line.pricebookEntryId] = TextEditingController(
        text:
            line.sellPrice == line.sellPrice.roundToDouble()
                ? line.sellPrice.round().toString()
                : line.sellPrice.toStringAsFixed(2),
      );
      _taxControllers[line.pricebookEntryId] = TextEditingController(
        text: line.taxPercent > 0 ? line.taxPercent.toString() : '',
      );
    }
  }

  void _continueFromEditPrice() {
    if (!_editPriceCanContinue) return;
    _syncLineEditsFromControllers();
    controller.internalQuoteLineEdits = List<InternalQuoteLineEdit>.from(
      _lineEdits!,
    );
    controller.internalMatchedRateEntry = _selectedPricebookEntry;
    controller.internalPricebookEntries = _quotePricebookEntries;
    controller.internalContainerSize = _selectedContainerSize;
    setState(() => _step = _getQuoteStep!);
  }

  void _continueFromAccount() {
    SalesAccountChoice? selected;
    for (final choice in _salesAccounts) {
      if (choice.id == _selectedSalesAccountId) selected = choice;
    }
    if (selected == null) {
      Get.snackbar('Required', 'Please select an account');
      return;
    }
    controller.selectedSalesAccount.value = selected;
    setState(() => _step = _routeStep);
  }

  void _initializeForm() {
    if (!mounted) return;

    if (!widget.embedded) {
      controller.clearSelections();
    }
    if (controller.validFromDate.value == null) {
      final now = DateTime.now();
      controller.validFromDate.value =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.bindFlowNavigator(Navigator.of(context));
  }

  void _continueFromRoute() {
    final originMissing = controller.selectedOriginPort.value == null;
    final destinationMissing = controller.selectedDestinationPort.value == null;
    setState(() {
      _originError = originMissing ? 'Please select an origin port' : null;
      _destinationError =
          destinationMissing ? 'Please select a destination port' : null;
    });
    if (originMissing || destinationMissing) return;
    _viewPrices();
  }

  Future<void> _viewPrices() async {
    final found = await controller.searchPricebook(presentResults: false);
    if (!mounted || !found) return;
    setState(() {
      _selectedMloEntries = null;
      _step = _ratesStep;
      _marginLoading = true;
    });
    final margin = await _fetchAccountMargin();
    if (!mounted) return;
    setState(() {
      _accountMarginPct = margin;
      _marginLoading = false;
    });
  }

  void _goToReview() {
    if (_picksAccount) return;
    if (_selectedMloEntries == null || _selectedMloEntries!.isEmpty) {
      Get.snackbar('Required', 'Please select a rate');
      return;
    }
    setState(() => _step = _reviewStep);
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  bool _isOffstage(BuildContext context) {
    var hidden = false;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Offstage) {
        hidden = widget.offstage;
        return false;
      }
      return true;
    });
    return hidden;
  }

  void _swapPorts() {
    final origin = controller.selectedOriginPort.value;
    final destination = controller.selectedDestinationPort.value;
    final originSector = controller.selectedOriginSector.value;
    final destinationSector = controller.selectedDestinationSector.value;
    controller.selectedOriginPort.value = destination;
    controller.selectedDestinationPort.value = origin;
    controller.selectedOriginSector.value = destinationSector;
    controller.selectedDestinationSector.value = originSector;
    setState(() {
      _originError = null;
      _destinationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffstage(context)) {
      controller.bindFlowNavigator(Navigator.of(context));
    }
    final body = Obx(
      () => Stack(
        children: [
          ColoredBox(
            color: _pageBg,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntro(),
                        const SizedBox(height: 18),
                        _buildStepper(),
                        const SizedBox(height: 18),
                        if (_step == _accountStep)
                          _buildAccountStep()
                        else if (_step == _routeStep)
                          _buildRouteStep()
                        else if (_step == _ratesStep)
                          _buildRatesStep()
                        else if (_editPriceStep != null &&
                            _step == _editPriceStep)
                          _buildEditPriceStep()
                        else if (_getQuoteStep != null &&
                            _step == _getQuoteStep)
                          _buildInternalGetQuoteStep()
                        else if (_step == _reviewStep)
                          _buildReviewStep(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
          if (controller.isPortsLoading.value) _buildLoadingOverlay(),
        ],
      ),
    );

    if (widget.embedded) {
      return PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _step > 0) _goBack();
        },
        child: body,
      );
    }

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) {
          _goBack();
          return;
        }
        if (didPop) {
          controller.clearSelections();
          controller.clearFlowNavigator();
        }
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _titleColor,
          elevation: 0,
          title: const Text('Search Rates'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_step > 0) {
                _goBack();
                return;
              }
              Navigator.of(context).maybePop();
            },
          ),
        ),
        body: body,
      ),
    );
  }

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Rates',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Find the best rates in seconds with MPRS Genie',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    final labels =
        _picksAccount
            ? const ['Account', 'Route', 'Rates', 'Price', 'Get a quote']
            : const ['Route', 'Rates', 'Review'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) Expanded(child: _stepConnector(active: _step >= i)),
          _stepNode(index: i, number: '${i + 1}', label: labels[i]),
        ],
      ],
    );
  }

  Widget _stepConnector({required bool active}) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: active ? AppColors.main : const Color(0xFFD9DEE8),
    );
  }

  Widget _stepNode({
    required int index,
    required String number,
    required String label,
  }) {
    final reached = _step >= index;
    return InkWell(
      onTap: () {
        if (index < _step) {
          setState(() => _step = index);
        } else if (_accountStep != null &&
            index == _routeStep &&
            _step == _accountStep) {
          _continueFromAccount();
        } else if (index == _ratesStep && _step == _routeStep) {
          _continueFromRoute();
        } else if (_editPriceStep != null &&
            index == _editPriceStep &&
            _step == _ratesStep) {
          if (_selectedMloEntries == null || _selectedMloEntries!.isEmpty) {
            Get.snackbar('Required', 'Please select a rate');
          } else {
            _openPriceSheet(_selectedMloEntries!);
          }
        } else if (_getQuoteStep != null &&
            index == _getQuoteStep &&
            _step == _editPriceStep) {
          _continueFromEditPrice();
        } else if (index == _reviewStep && _step == _ratesStep) {
          _goToReview();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached ? AppColors.main : const Color(0xFFE8EDF5),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: reached ? Colors.white : _muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
              color: reached ? AppColors.main : _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: _swapPorts,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.main, width: 1.4),
          ),
          child: Icon(Icons.swap_vert, color: AppColors.main, size: 20),
        ),
      ),
    );
  }

  Widget _buildAccountStep() {
    final visible = _visibleSalesAccounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the account this rate search is for.',
          style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _accountSearchCtrl,
          onChanged: (value) => setState(() => _accountSearchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search accounts',
            hintStyle: const TextStyle(color: _muted, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _muted, size: 22),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.main, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_salesAccountsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty && _accountSearchQuery.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No accounts match your search.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          )
        else
          ...visible.map(_accountTile),
      ],
    );
  }

  Widget _accountTile(SalesAccountChoice choice) {
    final selected = choice.id == _selectedSalesAccountId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFF3F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedSalesAccountId = choice.id);
            controller.selectedSalesAccount.value = choice;
            if (choice.isSelf) {
              controller.lastOpportunityId = null;
              controller.lastValidTill = null;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.main : _cardBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.main : _muted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                      if (choice.isSelf)
                        const Text(
                          'You',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPortCard(
          type: 'Origin',
          caption: 'From (Origin Port)',
          emptyHint: 'Select origin port',
          portVar: controller.selectedOriginPort,
          errorText: _originError,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
            child: _buildSwapButton(),
          ),
        ),
        _buildPortCard(
          type: 'Dest',
          caption: 'To (Destination Port)',
          emptyHint: 'Select destination port',
          portVar: controller.selectedDestinationPort,
          errorText: _destinationError,
        ),
        const SizedBox(height: 16),
        _buildReadOnlyCard(
          icon: Icons.directions_boat_outlined,
          caption: 'Mode of Shipment',
          value: 'Ocean',
        ),
        const SizedBox(height: 12),
        _buildDateCard(context),
        const SizedBox(height: 20),
        const Text(
          'Cargo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Containers, weight, and commodity',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        Obx(
          () => buildInputField(
            label: 'Number of Containers',
            controller: controller.quantityCtrl,
            type: TextInputType.number,
            isRequired: true,
            errorText: controller.quantityError.value,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              if (controller.quantityCtrl.text.trim().isNotEmpty) {
                controller.quantityError.value = null;
              }
            },
          ),
        ),
        Obx(
          () => buildInputField(
            label: 'Weight per container (in KG)',
            controller: controller.weightCtrl,
            type: const TextInputType.numberWithOptions(decimal: true),
            isRequired: true,
            errorText: controller.weightError.value,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) {
              if (controller.weightCtrl.text.trim().isNotEmpty) {
                controller.weightError.value = null;
              }
            },
          ),
        ),
        _buildCommodityField(controller, context),
        buildInputField(
          label: 'Cargo Value (in USD) (Optional)',
          controller: controller.cargoValueCtrl,
          type: const TextInputType.numberWithOptions(decimal: true),
          hint: 'Optional',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
        ),
      ],
    );
  }

  Widget _buildRatesStep() {
    final groups = _groupByMlo(controller.lastSearchEntries);
    final keys = groups.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${keys.length} rate${keys.length == 1 ? '' : 's'} for this route',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildRateCard(keys[i], groups[keys[i]]!),
        ],
      ],
    );
  }

  Map<String, List<PricebookEntryModel>> _groupByMlo(
    List<PricebookEntryModel> entries,
  ) {
    final map = <String, List<PricebookEntryModel>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.mloCode, () => []).add(entry);
    }
    return map;
  }

  Widget _buildRateCard(String mloCode, List<PricebookEntryModel> entries) {
    final sorted = [...entries]..sort((a, b) {
      final aIs20 = a.containerSize.contains('20');
      final bIs20 = b.containerSize.contains('20');
      if (aIs20 && !bIs20) return -1;
      if (!aIs20 && bIs20) return 1;
      return a.containerSize.compareTo(b.containerSize);
    });
    final first = sorted.first;
    final selected =
        _selectedMloEntries != null &&
        _selectedMloEntries!.isNotEmpty &&
        _selectedMloEntries!.first.mloCode == mloCode;
    final origin = _portName(controller.selectedOriginPort.value);
    final destination = _portName(controller.selectedDestinationPort.value);
    final routing = PricebookEntryCardDetails.routingLabel(first);
    final isDirect = routing.toLowerCase() == 'direct';
    final transit = PricebookEntryCardDetails.transitLabel(first);
    final mlo = mloCode.trim().isEmpty ? 'N/A' : mloCode.trim();

    return Material(
      color: Colors.white,
      elevation: selected ? 2 : 0,
      shadowColor: AppColors.main.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() => _selectedMloEntries = sorted);
          _openPriceSheet(sorted);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.main : _cardBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F7FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        origin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.main,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_marginLoading)
                      const SizedBox(
                        height: 52,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          for (var i = 0; i < sorted.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _priceChip(sorted[i])),
                          ],
                        ],
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _metaTile('Transit Time', transit)),
                        const SizedBox(width: 8),
                        Expanded(child: _metaTile('MLO', mlo)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metaTile(
                            'Routing',
                            isDirect ? 'Direct' : routing,
                            valueColor:
                                isDirect
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedMloEntries = sorted);
                          _openPriceSheet(sorted);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.main,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Prices',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaTile(String title, String value, {Color? valueColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _titleColor,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceChip(PricebookEntryModel entry) {
    final result = PricingCalculator.calculate(
      entry: entry,
      userType: AuthDataHelper.getUserType(),
      accountMarginPct: _accountMarginPct,
      forceMargin: true,
    );
    final currency =
        entry.mprsCurrencyC?.isNotEmpty == true ? entry.mprsCurrencyC! : 'USD';
    final size = entry.containerSize.isEmpty ? '—' : entry.containerSize;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$currency ${_formatPrice(result.sellPrice)}',
            style: const TextStyle(
              color: AppColors.main,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$size FCL',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  Widget _buildEditPriceStep() {
    final lines = _lineEdits ?? [];
    final hasInvalidSell = lines.any(_lineSellBelowBuy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edit Quote Line Item',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Adjust sell price and tax for each charge',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 14),
        if (lines.isEmpty)
          const Text(
            'Select a rate and container size first.',
            style: TextStyle(fontSize: 13, color: _muted),
          )
        else ...[
          for (final line in lines) _buildEditPriceRow(line),
          if (hasInvalidSell)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sell price must be at or above the buy price for every line.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEditPriceMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _titleColor,
        ),
      ),
    );
  }

  InputDecoration _editPriceFieldDecoration({
    required String hint,
    bool hasError = false,
  }) {
    final borderColor = hasError ? Colors.red.shade400 : _cardBorder;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: hasError ? Colors.red.shade400 : AppColors.main,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
    );
  }

  Widget _buildEditPriceRow(InternalQuoteLineEdit line) {
    final sellCtrl = _sellControllers[line.pricebookEntryId];
    final taxCtrl = _taxControllers[line.pricebookEntryId];
    if (sellCtrl == null || taxCtrl == null) return const SizedBox.shrink();
    final belowBuy = _lineSellBelowBuy(line);
    final buyLabel = '${line.currency} ${_formatPrice(line.buyPrice)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: belowBuy ? Colors.red.shade300 : _cardBorder,
            width: belowBuy ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.productName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _titleColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildEditPriceMetaChip('Qty ${line.quantity}'),
                _buildEditPriceMetaChip(line.currency),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buy price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD6E4FF)),
                        ),
                        child: Text(
                          buyLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sell price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sellCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: belowBuy ? Colors.red.shade700 : _titleColor,
                        ),
                        decoration: _editPriceFieldDecoration(
                          hint: 'Enter sell price',
                          hasError: belowBuy,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tax (%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: taxCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
              decoration: _editPriceFieldDecoration(
                hint: 'Optional',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final selected =
        _selectedMloEntries?.isNotEmpty == true
            ? _selectedMloEntries!.first
            : null;
    final sizes = (_selectedMloEntries ?? [])
        .map((e) => e.containerSize)
        .where((s) => s.isNotEmpty)
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Confirm the route, cargo, and selected rate',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        _reviewCard('Route', [
          _reviewLine('Origin', _portName(controller.selectedOriginPort.value)),
          _reviewLine(
            'Destination',
            _portName(controller.selectedDestinationPort.value),
          ),
          _reviewLine('Mode of Shipment', controller.selectedMode.value),
          _reviewLine(
            'Valid From',
            _formatDisplayDate(controller.validFromDate.value),
          ),
        ]),
        const SizedBox(height: 12),
        _reviewCard('Cargo', [
          _reviewLine('Containers', controller.quantityCtrl.text.trim()),
          _reviewLine(
            'Weight per container',
            '${controller.weightCtrl.text.trim()} KG',
          ),
          _reviewLine(
            'Commodity',
            controller.commodityDisplay.value.isEmpty
                ? controller.commodityCtrl.text.trim()
                : controller.commodityDisplay.value,
          ),
          if (controller.cargoValueCtrl.text.trim().isNotEmpty)
            _reviewLine(
              'Cargo value',
              '${controller.cargoValueCtrl.text.trim()} USD',
            ),
        ]),
        const SizedBox(height: 12),
        _reviewCard('Selected rate', [
          _reviewLine(
            'MLO',
            selected?.mloCode.isNotEmpty == true ? selected!.mloCode : 'N/A',
          ),
          _reviewLine(
            'Routing',
            selected == null
                ? '—'
                : PricebookEntryCardDetails.routingLabel(selected),
          ),
          _reviewLine(
            'Transit',
            selected == null
                ? '—'
                : PricebookEntryCardDetails.transitLabel(selected),
          ),
          _reviewLine('Container sizes', sizes.isEmpty ? '—' : sizes),
        ]),
      ],
    );
  }

  Widget _reviewCard(String title, List<Widget> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 8),
          ...lines,
        ],
      ),
    );
  }

  Widget _reviewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _portName(PortModel? port) {
    final name = port?.name?.trim() ?? '';
    return name.isEmpty ? '—' : name;
  }

  Future<double?> _fetchAccountMargin() async {
    try {
      final token = AuthDataHelper.getToken();
      final accountId = AuthDataHelper.getAccountId();
      final response = await http.get(
        Uri.parse(ApiConstants.userMarginAccount(accountId)),
        headers: AppConfig.mergeApiHeaders({'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) return null;
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
          record['Margin__c'] ??
          record['margin'] ??
          record['accountMargin'] ??
          record['account_margin'] ??
          record['value'];
      if (raw == null) return null;
      return double.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  void _continueFromReview() {
    final entries = _selectedMloEntries;
    if (entries == null || entries.isEmpty) {
      Get.snackbar('Required', 'Please select a rate');
      return;
    }
    _openPriceSheet(entries);
  }

  Widget _buildInternalGetQuoteStep() {
    final matched =
        controller.internalMatchedRateEntry ?? _selectedPricebookEntry;
    final bundle =
        controller.internalPricebookEntries ?? _quotePricebookEntries;
    final edits = controller.internalQuoteLineEdits ?? _lineEdits;
    if (matched == null || bundle == null || edits == null || edits.isEmpty) {
      return const Text(
        'Complete the Price step to get a quote.',
        style: TextStyle(fontSize: 13, color: _muted),
      );
    }
    final pol = _portName(controller.selectedOriginPort.value);
    final pod = _portName(controller.selectedDestinationPort.value);
    final originPort = controller.allPorts.firstWhere(
      (p) => p.name == pol,
      orElse: () => PortModel(),
    );
    final destPort = controller.allPorts.firstWhere(
      (p) => p.name == pod,
      orElse: () => PortModel(),
    );
    final mappedLoadType =
        controller.selectedMode.value.toLowerCase() == 'air' ? 'AIR' : 'FCL';

    return GetQuoteScreen(
      key: ValueKey(
        '${matched.id}_${controller.internalContainerSize ?? _selectedContainerSize}',
      ),
      embeddedInSearchFlow: true,
      selectedMloCode: matched.mloCode,
      initialPol: pol,
      initialPod: pod,
      initialPolId: originPort.portId,
      initialPodId: destPort.portId,
      initialLoadType: mappedLoadType,
      initialShipmentMode: controller.selectedMode.value,
      initialContainerType: matched.containerType,
      initialContainerSize:
          controller.internalContainerSize ??
          _selectedContainerSize ??
          matched.containerSize,
      initialContainerQuantity: controller.quantityCtrl.text.trim(),
      initialWeightPerContainer: controller.weightCtrl.text.trim(),
      initialGoodsValue: controller.cargoValueCtrl.text.trim(),
      opportunityId: controller.lastOpportunityId,
      pricebookEntries: bundle,
      initialAccountMarginPct: _accountMarginPct,
      initialCommodity: controller.commodityCtrl.text,
      initialValidFrom: controller.validFromDate.value,
      initialValidTill: controller.lastValidTill,
      preparedLineEdits: List<InternalQuoteLineEdit>.from(edits),
    );
  }

  void _openPriceSheet(List<PricebookEntryModel> entries) {
    if (entries.isEmpty) return;
    final first = entries.first;
    final mloCode = first.mloCode;
    final allForMlo =
        controller.lastSearchAllRecords
            .where((e) => e.mloCode == mloCode)
            .toList();
    final uniqueSizes =
        entries
            .map((e) => e.containerSize)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
    final pol = _portName(controller.selectedOriginPort.value);
    final pod = _portName(controller.selectedDestinationPort.value);

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
            pricebookEntries: allForMlo.isNotEmpty ? allForMlo : entries,
            containerType:
                first.containerType.isNotEmpty
                    ? first.containerType
                    : controller.containerType,
            numberOfContainers: int.tryParse(
              controller.quantityCtrl.text.trim(),
            ),
            netWeightPerContainer: double.tryParse(
              controller.weightCtrl.text.trim(),
            ),
            userType: AuthDataHelper.getUserType(),
            accountMarginPct: _accountMarginPct,
            onConfirm: (selectedContainerString) async {
              final matched = entries.firstWhere(
                (e) =>
                    selectedContainerString?.contains(e.containerSize) == true,
                orElse: () => first,
              );
              if (_picksAccount) {
                final sizeLabel =
                    selectedContainerString?.trim().isNotEmpty == true
                        ? selectedContainerString!.trim()
                        : matched.containerSize;
                final qty =
                    int.tryParse(controller.quantityCtrl.text.trim()) ?? 1;
                final pricebook = allForMlo.isNotEmpty ? allForMlo : entries;
                final edits = buildInternalQuoteLineEdits(
                  allEntries: pricebook,
                  selectedContainerSize: sizeLabel,
                  quantity: qty,
                  userType: AuthDataHelper.getUserType(),
                  accountMarginPct: _accountMarginPct,
                );
                if (!mounted) return;
                setState(() {
                  _selectedPricebookEntry = matched;
                  _selectedContainerSize = sizeLabel;
                  _quotePricebookEntries = pricebook;
                  _primeLineEditControllers(edits);
                  _step = _editPriceStep!;
                });
                return;
              }

              final mappedLoadType =
                  controller.selectedMode.value.toLowerCase() == 'air'
                      ? 'AIR'
                      : 'FCL';
              final originPort = controller.allPorts.firstWhere(
                (p) => p.name == pol,
                orElse: () => PortModel(),
              );
              final destPort = controller.allPorts.firstWhere(
                (p) => p.name == pod,
                orElse: () => PortModel(),
              );

              final backToPreviousStep = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder:
                      (_) => GetQuoteScreen(
                        selectedMloCode: matched.mloCode,
                        initialPol: pol,
                        initialPod: pod,
                        initialPolId: originPort.portId,
                        initialPodId: destPort.portId,
                        initialLoadType: mappedLoadType,
                        initialShipmentMode: controller.selectedMode.value,
                        initialContainerType: matched.containerType,
                        initialContainerSize: matched.containerSize,
                        initialContainerQuantity:
                            controller.quantityCtrl.text.trim(),
                        initialWeightPerContainer:
                            controller.weightCtrl.text.trim(),
                        initialGoodsValue:
                            controller.cargoValueCtrl.text.trim(),
                        opportunityId: controller.lastOpportunityId,
                        pricebookEntries:
                            allForMlo.isNotEmpty ? allForMlo : entries,
                        initialAccountMarginPct: _accountMarginPct,
                        initialCommodity: controller.commodityCtrl.text,
                        initialValidFrom: controller.validFromDate.value,
                        initialValidTill: controller.lastValidTill,
                      ),
                ),
              );
              if (!mounted || backToPreviousStep != true) return;
              setState(() => _step = _ratesStep);
            },
          ),
    );
  }

  Widget _buildBottomBar() {
    if (_step == _ratesStep) return const SizedBox.shrink();
    if (_getQuoteStep != null && _step == _getQuoteStep) {
      return const SizedBox.shrink();
    }
    final searching = controller.isSearchingPricebook.value;
    final String label = 'Continue';
    final VoidCallback? action =
        _step == _accountStep
            ? _continueFromAccount
            : _step == _routeStep
            ? _continueFromRoute
            : (_editPriceStep != null && _step == _editPriceStep)
            ? _continueFromEditPrice
            : _continueFromReview;
    final bool accountContinueBlocked =
        _step == _accountStep && _selectedSalesAccountId == null;
    final bool editPriceBlocked =
        _editPriceStep != null &&
        _step == _editPriceStep &&
        !_editPriceCanContinue;
    return Container(
      color: _pageBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    searching || accountContinueBlocked || editPriceBlocked
                        ? null
                        : action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  disabledBackgroundColor: editPriceBlocked
                      ? const Color(0xFFD0D5DD)
                      : AppColors.main.withValues(alpha: 0.6),
                  disabledForegroundColor: editPriceBlocked
                      ? const Color(0xFF98A2B3)
                      : Colors.white.withValues(alpha: 0.9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    searching
                        ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Secure  •  Fast  •  Reliable',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortCard({
    required String type,
    required String caption,
    required String emptyHint,
    required Rxn<PortModel> portVar,
    required String? errorText,
  }) {
    final ports = controller.getFilteredPorts(null);
    final port = portVar.value;
    final hasError = errorText != null;

    return SearchableDropdown(
      hint: emptyHint,
      label: '$type Port',
      selectedValue: port?.name,
      items: ports,
      onChanged: (val) {
        if (val == null) return;
        final selected = controller.allPorts.firstWhere((p) => p.name == val);
        portVar.value = selected;
        controller.updateSectorFromPort(val, type == 'Origin');
        setState(() {
          if (type == 'Origin') {
            _originError = null;
          } else {
            _destinationError = null;
          }
        });
      },
      triggerBuilder:
          (context, _) => _portCardBody(
            caption: caption,
            port: port,
            emptyHint: emptyHint,
            hasError: hasError,
            errorText: errorText,
          ),
    );
  }

  Widget _portCardBody({
    required String caption,
    required PortModel? port,
    required String emptyHint,
    required bool hasError,
    required String? errorText,
  }) {
    final title = _portTitle(port);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError ? Colors.red : _cardBorder,
              width: hasError ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _iconBadge(Icons.location_on_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isEmpty ? emptyHint : title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: title.isEmpty ? _muted : _titleColor,
                      ),
                    ),
                    if (port?.country != null && port!.country!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          port.country!,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasError ? Colors.red : _muted,
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _portTitle(PortModel? port) {
    if (port == null) return '';
    final name = (port.name ?? '').trim();
    final code = (port.portCode ?? '').trim();
    if (code.isEmpty || name.toUpperCase().contains(code.toUpperCase())) {
      return name;
    }
    return '$name ($code)';
  }

  Widget _buildReadOnlyCard({
    required IconData icon,
    required String caption,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          _iconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(BuildContext context) {
    final raw = controller.validFromDate.value;
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final initial = DateTime.tryParse(raw ?? '') ?? now;
        final date = await showDatePicker(
          context: context,
          initialDate: initial.isBefore(now) ? now : initial,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: DateTime(2100),
        );
        if (date == null) return;
        controller.validFromDate.value =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            _iconBadge(Icons.calendar_today_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valid From',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDisplayDate(raw),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  String _formatDisplayDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Select date';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
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
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Widget _iconBadge(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.main.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.main, size: 20),
    );
  }

  Widget _buildSectionTitle(String title, {bool isRequired = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child:
        isRequired
            ? RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.indigo,
                ),
                children: [
                  TextSpan(text: title),
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
            : Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.indigo,
              ),
            ),
  );
  Widget buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType type = TextInputType.text,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    final hasError = errorText != null;
    final borderColor = hasError ? Colors.red : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: type,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            decoration: InputDecoration(
              label:
                  isRequired
                      ? RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                          children: [
                            TextSpan(text: label),
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                      : null,
              labelText: isRequired ? null : label,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : AppColors.main,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommodityField(
    SearchRouteController controller,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Commodity', isRequired: true),
          Obx(() {
            final hasError = controller.commodityError.value != null;
            final borderColor = hasError ? Colors.red : Colors.grey.shade300;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showCommodityPicker(context, controller),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: hasError ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.commodityDisplay.value.isEmpty
                                ? 'Select Commodity'
                                : controller.commodityDisplay.value,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  controller.commodityDisplay.value.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: hasError ? Colors.red : AppColors.main,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      controller.commodityError.value!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showCommodityPicker(
    BuildContext context,
    SearchRouteController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _CommodityPickerSheet(
            onSelected: (hsCode) {
              controller.commodityCtrl.text = hsCode;
              controller.commodityDisplay.value = hsCode;
              controller.commodityError.value = null;
            },
          ),
    );
  }

  Widget _buildLoadingOverlay() => Positioned.fill(
    child: Container(
      color: Colors.white.withOpacity(0.8),
      child: const Center(child: CircularProgressIndicator()),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Commodity picker bottom sheet with search + pagination
// ─────────────────────────────────────────────────────────────────────────────
class _CommodityPickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const _CommodityPickerSheet({required this.onSelected});

  @override
  State<_CommodityPickerSheet> createState() => _CommodityPickerSheetState();
}

class _CommodityPickerSheetState extends State<_CommodityPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _items = [];

  int _page = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      if (!_isLoading && _page < _totalPages) {
        _fetch(reset: false);
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetch(reset: true);
    });
  }

  Future<void> _fetch({required bool reset}) async {
    if (_isLoading) return;
    if (!reset && _page >= _totalPages) return;

    setState(() => _isLoading = true);

    try {
      final token = AuthDataHelper.getToken();
      final nextPage = reset ? 1 : _page + 1;
      final query = Uri.encodeComponent(_searchCtrl.text.trim());
      final url = '${ApiConstants.commodities}?page=$nextPage&name=$query';

      final response = await http.get(
        Uri.parse(url),
        headers: AppConfig.mergeApiHeaders({'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data =
            (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        final meta = body['meta'] as Map<String, dynamic>?;

        setState(() {
          if (reset) _items.clear();
          _items.addAll(data);
          _page = nextPage;
          _totalPages = (meta?['totalPages'] as num?)?.toInt() ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Commodity fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Select Commodity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StatefulBuilder(
              builder:
                  (_, ss) => TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      ss(() {});
                      _onSearchChanged(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by HS code or description...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      suffixIcon:
                          _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ss(() {});
                                  _fetch(reset: true);
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.main,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // List
          Expanded(
            child:
                _items.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? Center(
                      child: Text(
                        'No commodities found',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                    : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _items.length + (_isLoading ? 1 : 0),
                      separatorBuilder:
                          (_, __) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      itemBuilder: (ctx, i) {
                        if (i == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final item = _items[i];
                        final hsCode = item['HS_Code__c'] as String? ?? '';
                        return ListTile(
                          title: Text(
                            hsCode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 18,
                          ),
                          onTap: () {
                            widget.onSelected(hsCode);
                            Navigator.pop(context);
                          },
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
