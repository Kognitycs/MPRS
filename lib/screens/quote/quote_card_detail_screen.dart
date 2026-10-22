import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/model/common/Booking_success.dart';
import 'package:mprs_android/service/booking_service.dart';
import 'package:mprs_android/model/get_quote_detail_model.dart';
import 'package:mprs_android/model/get_shipment_model.dart';
import 'package:mprs_android/model/order_document_model.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/core/utils/url_launcher_helper.dart';
import 'package:mprs_android/screens/support_screen.dart';

/// Quote card detail — matches Quote Details design; opens from shipment or saved quote card.
class QuoteCardDetailScreen extends StatefulWidget {
  final SavedQuotationsModel quote;
  final Records? shipmentRecord;

  const QuoteCardDetailScreen({
    super.key,
    required this.quote,
    this.shipmentRecord,
  });

  /// Opens detail without breaking nested navigators (home tab / dashboard).
  static void open(BuildContext context, SavedQuotationsModel quote) {
    final id = quote.id?.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quote id is missing — cannot open details.'),
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => QuoteCardDetailScreen(quote: quote),
      ),
    );
  }

  factory QuoteCardDetailScreen.fromShipment(Records record) {
    num? total;
    final rawTotal = record.grandTotal;
    if (rawTotal is num) {
      total = rawTotal;
    } else if (rawTotal != null) {
      total = num.tryParse(rawTotal.toString().replaceAll(',', ''));
    }

    return QuoteCardDetailScreen(
      shipmentRecord: record,
      quote: SavedQuotationsModel(
        id: record.id?.toString(),
        name: record.name?.toString(),
        totalPrice: total,
        currencyIsoCode: 'INR',
        loadType: record.leadTypeC?.toString(),
        containerType: record.containerTypeC?.toString(),
        containerSize: record.containerSizeC?.toString(),
        modeOfShipment: record.modeOfShipmentC?.toString(),
        netWeight:
            record.netWeightKgsC is num
                ? record.netWeightKgsC as num
                : num.tryParse(record.netWeightKgsC?.toString() ?? ''),
        grossWeight:
            record.netWeightKgsC is num
                ? record.netWeightKgsC as num
                : num.tryParse(record.netWeightKgsC?.toString() ?? ''),
        goodsValue:
            record.goodsValueC is num
                ? record.goodsValueC as num
                : num.tryParse(record.goodsValueC?.toString() ?? ''),
        expirationDate: record.expirationDate?.toString(),
        status: record.status?.toString(),
        opportunityName: record.opportunity?.name?.toString(),
        originPortR:
            record.originPortName != null
                ? PortMaster(name: record.originPortName.toString())
                : null,
        destinationPortR:
            record.destinationPortName != null
                ? PortMaster(name: record.destinationPortName.toString())
                : null,
      ),
    );
  }

  @override
  State<QuoteCardDetailScreen> createState() => _QuoteCardDetailScreenState();
}

class _QuoteCardDetailScreenState extends State<QuoteCardDetailScreen> {
  late final SavedQuotationsController _controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SavedQuotationsController>()) {
      _controller = Get.find<SavedQuotationsController>();
    } else {
      _controller = Get.put(SavedQuotationsController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.activeQuoteDetail = widget.quote;
      final id = widget.quote.id?.trim() ?? '';
      if (id.isNotEmpty) {
        _controller.fetchQuoteDetails(id, seedQuote: widget.quote);
      }
    });
  }

  @override
  void dispose() {
    _controller.clearDetailState();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }

  String get _quoteId => (_quoteData.id ?? widget.quote.id ?? '').trim();

  Future<void> _bookQuote({
    required String quoteId,
    BuildContext? dialogContext,
  }) async {
    ProgressLoader.show(context);
    final result = await BookingService.reserveQuoteSpace(quoteId);
    if (mounted) ProgressLoader.hide(context);
    if (!mounted) return;

    if (!result.success) {
      Get.snackbar(
        'Error',
        result.message,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
      return;
    }

    final dialogNav = dialogContext != null
        ? Navigator.of(dialogContext)
        : Navigator.of(context, rootNavigator: true);
    if (dialogNav.canPop()) {
      dialogNav.pop();
    }

    await BookingSuccessScreen.show(context);
  }

  void _showBookingDialog({required String quoteId}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppColors.main,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Confirm Your Booking',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You’re now Genie-Fied.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'By continuing, you authorize MPRS to ',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Confirm the quoted commercial terms',
                              style: TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Create your shipment order request',
                              style: TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Need help? Speak with your Account Manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.main,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!_isAdminUser)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            await _bookQuote(
                              quoteId: quoteId,
                              dialogContext: dialogContext,
                            );
                          },
                          child: const Text(
                            'Reserve Your Space',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onReservePressed() {
    if (_isAdminUser) return;
    final quoteId = _quoteId;
    if (quoteId.isEmpty) {
      Get.snackbar(
        'Error',
        'Quote id is missing — cannot reserve space.',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
      return;
    }
    _showBookingDialog(quoteId: quoteId);
  }

  SavedQuotationsModel get _quoteData {
    final merged = SavedQuotationsModel.merge([
      widget.quote,
      _controller.activeQuoteDetail,
    ]);
    return merged ?? widget.quote;
  }

  String _formatWeight(num? value) {
    if (value == null) return '—';
    return NumberFormat('#,##0').format(value);
  }

  String get _quoteNumber {
    final shipmentName = widget.shipmentRecord?.name?.toString();
    if (shipmentName != null && shipmentName.isNotEmpty) {
      return shipmentName;
    }
    final apiName = _quoteData.name;
    if (apiName != null && apiName.isNotEmpty) return apiName;

    final items = _controller.bookingDetailItems;
    if (items.isNotEmpty && items.first.lineNumber != null) {
      return 'QT-${items.first.lineNumber}';
    }
    final id = _quoteData.id ?? widget.quote.id ?? '';
    if (id.length >= 5) return 'QT-${id.substring(0, 5).toUpperCase()}';
    return '—';
  }

  String get _currencyIso {
    final items = _controller.bookingDetailItems;
    if (items.isNotEmpty &&
        items.first.currencyIsoCode != null &&
        items.first.currencyIsoCode!.isNotEmpty) {
      return items.first.currencyIsoCode!;
    }
    return _quoteData.currencyIsoCode ?? widget.quote.currencyIsoCode ?? 'INR';
  }

  String get _loadType {
    final type = _quoteData.loadType;
    if (type != null && type.isNotEmpty) return type;
    return '—';
  }

  String get _netWeightLabel => _formatWeight(_quoteData.netWeight);

  double _lineItemAmount(GetQuoteDetailModel item) {
    return item.lineAmountByFinalSell;
  }

  double _lineSellingUnitPrice(GetQuoteDetailModel item) {
    return item.sellingUnitPrice;
  }

  String get _goodsValueLabel {
    final symbol = _currencyIso == 'USD' ? '\$' : '₹';
    final value = _quoteData.goodsValue ?? widget.quote.goodsValue;
    if (value == null) return '—';
    return '$symbol${NumberFormat('#,##0').format(value)}';
  }

  String get _displayAmount {
    final symbol = _currencyIso == 'USD' ? '\$' : '₹';
    final items = _controller.bookingDetailItems;
    if (items.isNotEmpty) {
      return '$symbol${NumberFormat('#,##0').format(_grandTotal)}';
    }
    final price =
        _quoteData.totalPrice ??
        widget.quote.totalPrice ??
        widget.shipmentRecord?.grandTotal ??
        0;
    final numValue =
        price is num
            ? price
            : num.tryParse(price.toString().replaceAll(',', '')) ?? 0;
    return '$symbol${NumberFormat('#,##0').format(numValue)}';
  }

  String get _statusLabel {
    final status =
        widget.shipmentRecord?.status?.toString() ??
        _quoteData.status ??
        widget.quote.status;
    if (status != null && status.trim().isNotEmpty) return status.trim();
    return '—';
  }

  bool get _isAcceptedQuote =>
      SavedQuotationsModel.isAcceptedStatus(_statusLabel);

  bool get _isAdminUser => AuthDataHelper.isAdminUser();

  bool get _showReserveButton => !_isAcceptedQuote && !_isAdminUser;

  String _formatDisplayDate(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString();
    if (text.isEmpty) return '';
    try {
      final dt = DateTime.parse(text.split('T').first);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return text;
    }
  }

  String get _expirationDate {
    final formatted = _formatDisplayDate(
      widget.shipmentRecord?.expirationDate ?? _quoteData.expirationDate,
    );
    if (formatted.isNotEmpty) return formatted;
    return '—';
  }

  String get _originPort {
    final shipmentOrigin = widget.shipmentRecord?.originPortName?.toString();
    if (shipmentOrigin != null && shipmentOrigin.isNotEmpty) {
      return shipmentOrigin;
    }
    final shipmentPort = widget.shipmentRecord?.portOfLoadingC?.toString();
    if (shipmentPort != null && shipmentPort.isNotEmpty) return shipmentPort;

    final name = _quoteData.originPortR?.name ?? widget.quote.originPortR?.name;
    if (name != null && name.isNotEmpty) return name;
    return '—';
  }

  String get _destinationPort {
    final shipmentDest = widget.shipmentRecord?.destinationPortName?.toString();
    if (shipmentDest != null && shipmentDest.isNotEmpty) {
      return shipmentDest;
    }
    final shipmentPort = widget.shipmentRecord?.portOfDestinationC?.toString();
    if (shipmentPort != null && shipmentPort.isNotEmpty) return shipmentPort;

    final name =
        _quoteData.destinationPortR?.name ??
        widget.quote.destinationPortR?.name;
    if (name != null && name.isNotEmpty) return name;
    return '—';
  }

  double get _grandTotal {
    final items = _controller.bookingDetailItems;
    if (items.isEmpty) {
      final shipmentTotal = widget.shipmentRecord?.grandTotal;
      if (shipmentTotal is num) return shipmentTotal.toDouble();
      if (shipmentTotal != null) {
        return double.tryParse(shipmentTotal.toString().replaceAll(',', '')) ??
            _quoteData.totalPrice?.toDouble() ??
            widget.quote.totalPrice?.toDouble() ??
            0;
      }
      return _quoteData.totalPrice?.toDouble() ??
          widget.quote.totalPrice?.toDouble() ??
          0;
    }

    double sum = 0;
    for (final item in items) {
      sum += _lineItemAmount(item);
    }
    return sum;
  }

  String _formatMoney(num value) {
    final symbol = _currencyIso == 'USD' ? '\$' : '₹';
    return '$symbol${NumberFormat('#,##0.00').format(value)}';
  }

  Future<void> _downloadQuotePdf(OrderDocumentModel document) async {
    final url = document.downloadUrl;
    final title = document.displayTitle;

    if (!document.hasDownloadUrl || url == null) {
      Get.snackbar(
        'Download',
        'No download link available for $title.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!mounted) return;
    final opened = await openDocumentUrl(context, url, title: title);
    if (!opened && mounted) {
      Get.snackbar(
        'Download',
        'Unable to open $title. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF111827),
            size: 18,
          ),
          onPressed: _goBack,
        ),
        title: const Text(
          'Quotation Details',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: GetBuilder<SavedQuotationsController>(
        builder: (ctrl) {
          final lineItems = ctrl.bookingDetailItems;
          final showTopLoader = ctrl.isDetailLoading && lineItems.isEmpty;

          return Column(
            children: [
              if (showTopLoader)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.main,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 12),
                      _buildMetaRow(),
                      const SizedBox(height: 12),
                      _buildPriceCard(),
                      const SizedBox(height: 12),
                      _buildTitledDetails(),
                      const SizedBox(height: 12),
                      _buildPdfCard(),
                      const SizedBox(height: 12),
                      _buildLineItemsSection(
                        lineItems,
                        errorMessage: ctrl.errorMessage,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showReserveButton) _buildBottomButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLineItemsSection(
    List<GetQuoteDetailModel> items, {
    required String errorMessage,
  }) {
    if (items.isEmpty) {
      return _sectionCard(
        title: 'Quote Line Items',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'No line items found for this quote.',
            style: AppTextStyles.montserratMedium.copyWith(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }
    return _buildLineItemsCard(items);
  }

  String get _createdOn {
    final formatted = _formatDisplayDate(
      _quoteData.createdDateC ?? widget.quote.createdDateC,
    );
    return formatted.isEmpty ? '—' : formatted;
  }

  String get _sizeLabel {
    final raw =
        (_quoteData.containerSize ?? widget.quote.containerSize ?? '').trim();
    final feet = RegExp(r'(20|40|45)').firstMatch(raw);
    if (feet != null) return "${feet.group(1)}'";
    return raw;
  }

  Widget _detailShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: child,
    );
  }

  Widget _buildSummaryCard() {
    final route = [
      if (_originPort != '—') _originPort,
      if (_destinationPort != '—') _destinationPort,
    ].join('  →  ');
    return _detailShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.main,
                  size: 22,
                ),
              ),
              if (_sizeLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _sizeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              route.isEmpty ? 'Quotation' : route,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow() {
    return _detailShell(
      child: Row(
        children: [
          _metaCell('Valid Till', _expirationDate),
          _metaCell('Created On', _createdOn),
          _metaCell('Quote ID', _quoteNumber),
        ],
      ),
    );
  }

  Widget _metaCell(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return _detailShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All-in Rate',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _displayAmount,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.main,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitledDetails() {
    final rows = <MapEntry<String, String>>[
      MapEntry('Load Type', _loadType),
      MapEntry('Container Type', _quoteData.containerType ?? ''),
      MapEntry('Mode of Shipment', _quoteData.modeOfShipment ?? ''),
      MapEntry('Net Weight (KGS)', _netWeightLabel),
      MapEntry('Goods Value', _goodsValueLabel),
    ].where((row) {
      final value = row.value.trim();
      return value.isNotEmpty && value != '—';
    }).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return _detailShell(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 18, color: Color(0xFFE4E7EC)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    rows[i].value.trim().isEmpty ? '—' : rows[i].value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPdfCard() {
    final pdfs = _controller.quotePdfList;
    final pdfError = _controller.quotePdfError;

    return _sectionCard(
      title: 'Quote PDF',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_controller.isPdfLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.main,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (pdfs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                pdfError.isNotEmpty
                    ? pdfError
                    : 'No PDF documents available for this quote.',
                style: AppTextStyles.montserratMedium.copyWith(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            ...pdfs.map(_buildPdfDocumentRow),
        ],
      ),
    );
  }

  Widget _buildPdfDocumentRow(OrderDocumentModel document) {
    final hasUrl = document.hasDownloadUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: hasUrl ? Colors.red : Colors.grey.shade400,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.displayTitle,
                  style: AppTextStyles.montserratSemiBold.copyWith(
                    fontSize: 14,
                    color: hasUrl ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  document.displayFileName,
                  style: AppTextStyles.montserratMedium.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!hasUrl) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PDF not yet generated',
                    style: AppTextStyles.montserratMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.main,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: hasUrl ? () => _downloadQuotePdf(document) : null,
            icon: Icon(
              hasUrl
                  ? Icons.file_download_outlined
                  : Icons.hourglass_empty_rounded,
              color: hasUrl ? AppColors.main : AppColors.main,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsCard(List<GetQuoteDetailModel> items) {
    return _sectionCard(
      title: 'Quote Line Items',
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final qty = item.quantity?.toInt() ?? 0;
          final amount = _lineItemAmount(item);
          return Column(
            children: [
              if (index > 0) _divider(),
              InkWell(
                onTap: () => _showLineItemSheet(item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (item.product ?? item.description ?? 'Charge')
                                  .toUpperCase(),
                              style: AppTextStyles.montserratBold.copyWith(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.chargeType ?? '—',
                              style: AppTextStyles.montserratMedium.copyWith(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Qty $qty',
                            style: AppTextStyles.montserratMedium.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatMoney(amount),
                                style: AppTextStyles.montserratBold.copyWith(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade500,
                                size: 22,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _onReservePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Reserve Your Space',
              style: AppTextStyles.montserratSemiBold.copyWith(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.montserratBold.copyWith(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.montserratMedium.copyWith(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.montserratSemiBold.copyWith(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);

  void _showLineItemSheet(GetQuoteDetailModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product ?? 'Line item',
                  style: AppTextStyles.montserratBold.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                _infoRow('Charge type', item.chargeType ?? '—'),
                _infoRow('Quantity', '${item.quantity?.toInt() ?? 0}'),
                _infoRow('Amount', _formatMoney(_lineItemAmount(item))),
                _infoRow(
                  'Selling price',
                  _formatMoney(_lineSellingUnitPrice(item)),
                ),
                if (item.currencyIsoCode != null)
                  _infoRow('Currency', item.currencyIsoCode!),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
}
