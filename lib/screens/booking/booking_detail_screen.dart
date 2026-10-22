import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart';
import 'package:mprs_android/model/order_document_model.dart';
import 'package:mprs_android/core/utils/url_launcher_helper.dart';
import 'package:mprs_android/service/notification/shipment_status_notification_service.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  List<OrderDocumentModel> _documents = [];
  bool _documentsLoading = true;
  bool _uploadingDocument = false;
  String _documentsError = '';

  // Self-fetched detail when opened from a notification (no detailData in args).
  Map<String, dynamic>? _fetchedDetail;
  bool _isFetchingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fromNotification = _arguments?['fromNotification'] == true;
      if (fromNotification && _detailData == null) {
        _fetchDetailFromNotification();
      } else {
        _syncStatusNotifications();
      }
    });
  }

  Future<void> _syncStatusNotifications() async {
    final data = _detailData;
    if (data == null || data.isEmpty) return;
    await ShipmentStatusNotificationService.processOrderMap(data);
  }

  /// Fetch full booking detail when this screen is opened from a notification.
  Future<void> _fetchDetailFromNotification() async {
    final orderId = _orderId;
    if (orderId.isEmpty) return;

    if (!mounted) return;
    setState(() => _isFetchingDetail = true);

    try {
      final ctrl =
          Get.isRegistered<BookingController>()
              ? Get.find<BookingController>()
              : Get.put(BookingController());

      // Ensure we have a booking list to search for the quoteId.
      if (ctrl.allBookings.isEmpty) {
        await ctrl.getConfirmedBookings();
      }
      if (ctrl.inProgressBookings.isEmpty) {
        await ctrl.getInProgressBookings();
      }

      String quoteId = '';
      for (final b in [...ctrl.allBookings, ...ctrl.inProgressBookings]) {
        if (b.id?.toString() == orderId) {
          quoteId = b.quoteId?.toString() ?? '';
          break;
        }
      }

      if (quoteId.isNotEmpty) {
        await ctrl.fetchBookingDetails(quoteId: quoteId, orderId: orderId);
        if (ctrl.bookingDetailData is Map) {
          _fetchedDetail = Map<String, dynamic>.from(
            ctrl.bookingDetailData as Map,
          );
        }
      } else {
        debugPrint('⚠️ BookingDetail: quoteId not found for orderId=$orderId');
      }
    } catch (e) {
      debugPrint('⚠️ BookingDetail self-fetch: $e');
    }

    if (!mounted) return;
    setState(() => _isFetchingDetail = false);
    await _syncStatusNotifications();
  }

  Map? get _arguments {
    final args = Get.arguments;
    return args is Map ? args : null;
  }

  Map<String, dynamic>? get _detailData {
    // Self-fetched data takes priority when available.
    if (_fetchedDetail != null) return _fetchedDetail;

    final args = _arguments;
    if (args == null) return null;

    if (args['detailData'] is Map) {
      return Map<String, dynamic>.from(args['detailData'] as Map);
    }

    if (args['booking'] != null) {
      final booking = args['booking'];
      if (booking is Map) {
        return Map<String, dynamic>.from(booking);
      }
      try {
        return Map<String, dynamic>.from(booking.toJson() as Map);
      } catch (_) {}
    }

    return null;
  }

  /// Order id varies per booking — resolve from explicit arg or detail payload.
  String get _orderId {
    final args = _arguments;
    final explicit = args?['orderId']?.toString() ?? args?['id']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _detailData?['Id']?.toString() ?? '';
  }

  static const String _defaultUploadFileType = 'BL Draft (sent by Customer)';

  Future<void> _loadDocuments() async {
    if (_orderId.isEmpty) {
      setState(() {
        _documentsLoading = false;
        _documentsError = 'Order id not available';
      });
      return;
    }

    setState(() {
      _documentsLoading = true;
      _documentsError = '';
    });

    final response = await ApiProvider().fetchOrderDocuments(orderId: _orderId);

    if (!mounted) return;

    final allDocs = response.body ?? [];
    final hasDocuments = allDocs.isNotEmpty;

    ApiProvider.debugLogOrderDocuments(
      orderId: _orderId,
      documents: allDocs,
      source: 'BookingDetailScreen',
    );

    setState(() {
      _documents = allDocs;
      _documentsLoading = false;
      _documentsError =
          hasDocuments
              ? ''
              : (response.message ?? 'No documents available for this order.');
    });
  }

  Future<void> _onUploadDocument() async {
    if (_orderId.isEmpty) {
      showSnackBar(context, 'Order id not available');
      return;
    }
    if (_uploadingDocument) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    final file = picked.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      showSnackBar(context, 'Could not read the selected file');
      return;
    }

    setState(() => _uploadingDocument = true);

    final response = await ApiProvider().uploadOrderDocument(
      orderId: _orderId,
      filePath: path,
      fileName: file.name,
      fileType: _defaultUploadFileType,
    );

    if (!mounted) return;

    setState(() => _uploadingDocument = false);

    if (response.success == true) {
      showSnackBar(
        context,
        response.message ?? 'Document uploaded',
        backgroundColor: Colors.green.shade700,
      );
      await _loadDocuments();
      return;
    }

    showSnackBar(
      context,
      response.message ?? 'Failed to upload document',
      backgroundColor: Colors.red.shade700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailData = _detailData;

    return Stack(
      children: [
        _buildScaffold(context, detailData),
        if (_isFetchingDetail)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  String _text(Map<String, dynamic>? data, List<String> keys) {
    final direct = _readText(data, keys);
    if (direct.isNotEmpty) return direct;
    if (data == null) return '';
    for (final nestKey in ['Quote__r', 'Quote', 'Opportunity', 'quote']) {
      final nest = data[nestKey];
      if (nest is! Map) continue;
      final found = _readText(Map<String, dynamic>.from(nest), keys);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  String _readText(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return '';
    for (final key in keys) {
      final raw = data[key];
      if (raw is Map) {
        final name = raw['Name'] ?? raw['name'];
        final nested = name?.toString().trim() ?? '';
        if (nested.isNotEmpty && nested != 'null') return nested;
        continue;
      }
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _orNa(String value) => value.trim().isEmpty ? 'NA' : value.trim();

  String _sizeFeet(String raw) {
    final match = RegExp(r'(20|40|45)').firstMatch(raw);
    if (match != null) return match.group(1)!;
    return raw.trim();
  }

  String _weightLabel(String raw) {
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('kg') || lower.contains('lb')) return raw;
    final amount = num.tryParse(raw.replaceAll(',', ''));
    if (amount == null) return raw;
    final formatted =
        amount == amount.roundToDouble()
            ? amount.round().toString()
            : amount.toString();
    return '$formatted KG';
  }

  String _dateText(Map<String, dynamic>? data, List<String> keys) {
    final raw = _text(data, keys);
    if (raw.isEmpty) return '';
    return Records.formatListDate(raw) ?? raw;
  }

  String _amountText(Map<String, dynamic>? data) {
    final raw = _text(data, ['TotalAmount', 'GrandTotal', 'TotalPrice']);
    if (raw.isEmpty) return '';
    final amount = num.tryParse(raw.replaceAll(',', ''));
    final currency = _text(data, ['CurrencyIsoCode', 'MPRS_Currency__c']);
    if (amount == null) {
      return currency.isEmpty ? raw : '$currency $raw';
    }
    final formatted =
        amount == amount.roundToDouble()
            ? amount.round().toString()
            : amount.toStringAsFixed(2);
    return currency.isEmpty ? formatted : '$currency $formatted';
  }

  Widget _buildScaffold(
    BuildContext context,
    Map<String, dynamic>? detailData,
  ) {
    final origin = _text(detailData, ['Port_of_Loading__c', 'Origin_Port__c']);
    final destination = _text(detailData, [
      'Port_of_Destination__c',
      'Destination_Port__c',
    ]);
    final orderNo = _text(detailData, ['OrderNumber']);
    final reference = _text(detailData, ['OrderReferenceNumber']);
    final bl = _text(detailData, [
      'BL_Number__c',
      'Bill_of_Lading__c',
      'Bill_of_Lading_Number__c',
      'BOL_Number__c',
      'HBL__c',
      'MBL__c',
      'blNumber',
      'billOfLading',
    ]);
    final bookedDate = _dateText(detailData, ['Booked_Date__c']);
    final containerNo = _text(detailData, ['Container_Number__c']);
    final size = _sizeFeet(
      _text(detailData, [
        'Container_Size__c',
        'containerSize',
        'ContainerSize__c',
      ]),
    );
    final type = _text(detailData, [
      'Container_Type__c',
      'containerType',
      'ContainerType__c',
    ]);
    final vessel = _text(detailData, [
      'Vessel_Name__c',
      'Vessel__r',
      'vesselName',
      'MLO_Name__r',
    ]);
    final voyage = _text(detailData, ['Voyage_Number__c']);
    final onBoard = _dateText(detailData, ['On_Board_Date__c']);
    final mode = _text(detailData, [
      'Mode_of_Shipment__c',
      'Mode_Of_Shipment__c',
      'modeOfShipment',
    ]);
    final loadType = _text(detailData, [
      'Lead_Type__c',
      'Load_Type__c',
      'loadType',
    ]);
    final routing = _text(detailData, [
      'Routing__c',
      'routing',
      'Direct_Indirect_Routing__c',
      'Shipment_Routing__c',
      'Via_Port__c',
      'viaPort',
    ]);
    final commodity = _text(detailData, [
      'Commodity__c',
      'commodity',
      'Commodity_Description__c',
      'additionalInfo',
      'Cargo_Description__c',
      'Goods_Description__c',
      'Description',
    ]);
    final weight = _weightLabel(
      _text(detailData, [
        'Gross_Weight_KGS__c',
        'Gross_Weight__c',
        'Net_Weight_KGS__c',
        'Net_Weight__c',
        'weightPerContainer',
        'grossWeight',
      ]),
    );
    final account = _text(detailData, ['Account_Name', 'AccountName']);

    final meta = <_DetailFact>[
      _DetailFact('Vessel', _orNa(vessel)),
      _DetailFact('Load Type', _orNa(loadType)),
      _DetailFact('Mode', _orNa(mode)),
    ];

    final hasSize = size.trim().isNotEmpty;
    final info = <_DetailInfo>[
      if (reference.isNotEmpty && reference != orderNo)
        _DetailInfo(Icons.tag_outlined, 'Reference', reference),
      if (hasSize && containerNo.isNotEmpty)
        _DetailInfo(Icons.inventory_2_outlined, 'Container', containerNo),
      if (hasSize)
        _DetailInfo(Icons.straighten_outlined, 'Container Size', size)
      else if (containerNo.isNotEmpty)
        _DetailInfo(Icons.inventory_2_outlined, 'Container Size', containerNo),
      _DetailInfo(Icons.alt_route_outlined, 'Routing', _orNa(routing)),
      _DetailInfo(Icons.scale_outlined, 'Weight', _orNa(weight)),
      _DetailInfo(
        Icons.category_outlined,
        'Commodity',
        _orNa(commodity),
        fullWidth: true,
      ),
    ];

    final steps =
        <_Milestone>[
          _Milestone(
            'Booked',
            _dateText(detailData, ['Booked_Date__c']),
            Icons.check_rounded,
            account,
          ),
          _Milestone(
            'Container Picked Up',
            _dateText(detailData, ['Picked_Up_Date__c']),
            Icons.inventory_2_outlined,
            '',
          ),
          _Milestone(
            'Gate In',
            _dateText(detailData, ['Gated_In_Date__c']),
            Icons.login_rounded,
            origin,
          ),
          _Milestone(
            'On Board',
            onBoard,
            Icons.directions_boat_outlined,
            [vessel, voyage].where((part) => part.isNotEmpty).join(' • '),
          ),
          _Milestone(
            'Vessel Sailed',
            _dateText(detailData, ['Vessel_Sailed_Date__c']),
            Icons.sailing_outlined,
            vessel,
          ),
          _Milestone(
            'Discharged at Transshipment',
            _dateText(detailData, ['Transshipment_Discharge_Date__c']),
            Icons.swap_horiz_rounded,
            '',
          ),
          _Milestone(
            'Loaded at Transshipment',
            _dateText(detailData, ['Transshipment_Loaded_Date__c']),
            Icons.swap_horiz_rounded,
            '',
          ),
          _Milestone(
            'Discharged at Destination',
            _dateText(detailData, ['Discharged_Date__c']),
            Icons.anchor_outlined,
            destination,
          ),
          _Milestone(
            'Cargo Cleared',
            _dateText(detailData, ['Cleared_Date__c']),
            Icons.verified_outlined,
            '',
          ),
          _Milestone(
            'Empty Container Returned',
            _dateText(detailData, ['Returned_Date__c']),
            Icons.assignment_return_outlined,
            '',
          ),
        ].where((step) => step.date.isNotEmpty).toList();

    final amount = _amountText(detailData);
    final route = [
      if (origin.isNotEmpty) origin,
      if (destination.isNotEmpty) destination,
    ].join('  →  ');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Shipment Details',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildAppBarUploadButton(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(
              route: route,
              orderNo: orderNo.isNotEmpty ? orderNo : reference,
              bl: bl,
              containerType: type,
              bookedDate: bookedDate,
              ocean: !mode.toLowerCase().contains('air'),
            ),
            const SizedBox(height: 12),
            _metaCard(meta),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Route & Transit Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              _timelineCard(steps),
            ],
            if (info.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Shipment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              _infoCard(info),
            ],
            if (amount.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Charges Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              _chargesCard(amount),
            ],
            const SizedBox(height: 18),
            _buildBookingDocumentSection(context),
          ],
        ),
      ),
    );
  }

  Widget _headerCard({
    required String route,
    required String orderNo,
    required String bl,
    required String containerType,
    required String bookedDate,
    required bool ocean,
  }) {
    final line = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0039B5), Color(0xFF2F6BFF)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ocean ? Icons.directions_boat_filled : Icons.flight_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.isEmpty ? 'Shipment' : route,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (orderNo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Order: $orderNo', style: line),
                ],
                if (bl.isNotEmpty) Text('BL: $bl', style: line),
                if (containerType.isNotEmpty)
                  Text('Container type: $containerType', style: line),
                if (bookedDate.isNotEmpty)
                  Text('Booked date: $bookedDate', style: line),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaCard(List<_DetailFact> facts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < facts.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    facts[i].label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF98A2B3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facts[i].value,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineCard(List<_Milestone> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _timelineRow(
              steps[i],
              isLast: i == steps.length - 1,
              current: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _timelineRow(
    _Milestone step, {
    required bool isLast,
    required bool current,
  }) {
    final color = current ? AppColors.main : const Color(0xFF15803D);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, size: 15, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFE4E7EC)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (step.detail.isNotEmpty)
                    Flexible(
                      child: Text(
                        step.detail,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<_DetailInfo> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 3;
          final width = constraints.maxWidth / columns;
          return Wrap(
            children: [
              for (final item in items)
                SizedBox(
                  width: item.fullWidth ? constraints.maxWidth : width,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                    child: item.fullWidth
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: width - 12,
                                child: Column(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: const Color(0xFF667085),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF98A2B3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  item.value,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: const Color(0xFF667085),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF98A2B3),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.value,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chargesCard(String amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.main, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Amount',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDocumentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        if (_documentsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppColors.main),
            ),
          )
        else if (_documents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Text(
              _documentsError.isEmpty
                  ? 'No documents available for this order.'
                  : _documentsError,
              style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 4 : 2;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final document in _documents)
                    SizedBox(width: width, child: _buildDocumentCard(document)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildAppBarUploadButton() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _uploadingDocument ? null : _onUploadDocument,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.main),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploadingDocument)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.main,
                    ),
                  )
                else
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 18,
                    color: AppColors.main,
                  ),
                const SizedBox(width: 5),
                Text(
                  _uploadingDocument ? 'Uploading' : 'Upload Document',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.main,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(OrderDocumentModel document) {
    final icon = _documentIcon(document);
    final color = _documentIconColor(document);
    final subtitle =
        document.displayFileName == '—'
            ? (document.fileType?.trim().isNotEmpty == true
                ? document.fileType!.trim()
                : '')
            : document.displayFileName;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            document.hasDownloadUrl ? () => _downloadDocument(document) : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.file_download_outlined,
                      size: 18,
                      color:
                          document.hasDownloadUrl
                              ? AppColors.main
                              : const Color(0xFFD0D5DD),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  document.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isBillOfLading(String type) {
    return type.contains('lading') ||
        type.contains('b/l') ||
        type.contains('bill of') ||
        RegExp(r'(^|[^a-z])bl([^a-z]|$)').hasMatch(type);
  }

  IconData _documentIcon(OrderDocumentModel document) {
    final type =
        '${document.fileType ?? ''} ${document.fileName ?? ''}'.toLowerCase();
    if (type.contains('invoice')) return Icons.receipt_long_outlined;
    if (type.contains('pack')) return Icons.inventory_outlined;
    if (_isBillOfLading(type)) return Icons.article_outlined;
    if (type.contains('book')) return Icons.description_outlined;
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.description_outlined;
  }

  Color _documentIconColor(OrderDocumentModel document) {
    final type =
        '${document.fileType ?? ''} ${document.fileName ?? ''}'.toLowerCase();
    if (type.contains('invoice')) return const Color(0xFF15803D);
    if (type.contains('pack')) return const Color(0xFF7C3AED);
    if (_isBillOfLading(type)) return const Color(0xFF0891B2);
    return AppColors.main;
  }

  Future<void> _downloadDocument(OrderDocumentModel document) async {
    final url = document.downloadUrl;
    final title = document.displayTitle;

    if (url == null || !url.startsWith('http')) {
      Get.snackbar(
        'Download',
        'Unable to download $title',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black87,
      );
      return;
    }

    if (!mounted) return;
    final opened = await openDocumentUrl(context, url, title: title);
    if (opened) return;

    if (!mounted) return;
    Get.snackbar(
      'Download',
      'Could not open $title',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.black87,
    );
  }
}

class _DetailFact {
  final String label;
  final String value;
  const _DetailFact(this.label, this.value);
}

class _DetailInfo {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;
  const _DetailInfo(
    this.icon,
    this.label,
    this.value, {
    this.fullWidth = false,
  });
}

class _Milestone {
  final String title;
  final String date;
  final IconData icon;
  final String detail;
  const _Milestone(this.title, this.date, this.icon, this.detail);
}
