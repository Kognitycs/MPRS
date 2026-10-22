import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/screens/booking/booking_detail_screen.dart';
import 'package:mprs_android/screens/main_screen.dart';
import 'package:mprs_android/screens/quote/quote_card_detail_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

enum BookingScreenMode { book, shipments }

enum _InProgressQuoteFilter { all, draft, accepted }

class BookingScreen extends StatefulWidget {
  final BookingScreenMode mode;

  /// Kept for callers. Book mode always opens quotations.
  final int? initialSelectedTab;

  /// Quotations filter: 0 = All, 1 = Draft, 2 = Accepted.
  final int? initialQuoteFilterIndex;

  const BookingScreen({
    super.key,
    this.mode = BookingScreenMode.book,
    this.initialSelectedTab,
    this.initialQuoteFilterIndex,
  });

  /// Legacy alias — Book tab uses [BookingScreenMode.book].
  const BookingScreen.legacy({super.key, bool isOnlyNew = false})
    : mode = BookingScreenMode.book,
      initialSelectedTab = null,
      initialQuoteFilterIndex = null;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  late String controllerTag;
  late BookingController controller;
  late AnimationController _animController;
  late TabController _inProgressFilterController;

  int selectedTab = 0;
  String? _openingOrderId;

  // ── palette ──────────────────────────────────────────────
  static const Color _navy = Color(0xFF185FA5);
  static const Color _navyLight = Color(0xFFE8F1FB);
  static const Color _greenBg = Color(0xFFEAF3DE);
  static const Color _greenText = Color(0xFF3B6D11);
  static const Color _pageBg = Colors.white;
  static const Color _border = Color(0xFFE4E7EC);

  bool get _isAdminUser => AuthDataHelper.isAdminUser();


  bool _isCurrentTabLoading() {
    if (widget.mode == BookingScreenMode.book) {
      if (selectedTab == 0 && !_isAdminUser) return false;
      return controller.isInProgressLoading.value;
    }
    if (selectedTab == 0) return controller.isBookedLoading.value;
    return controller.isInProgressLoading.value;
  }

  @override
  void initState() {
    super.initState();

    selectedTab = widget.initialSelectedTab ?? 0;
    if (widget.mode == BookingScreenMode.book) {
      selectedTab = 1;
    }

    controllerTag =
        widget.mode == BookingScreenMode.book ? 'book_tab' : 'shipments_tab';
    controller = Get.put(BookingController(), tag: controllerTag);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );

    _inProgressFilterController = TabController(
      length: _InProgressQuoteFilter.values.length,
      vsync: this,
      initialIndex: (widget.initialQuoteFilterIndex ?? 0).clamp(
        0,
        _InProgressQuoteFilter.values.length - 1,
      ),
    );
    _inProgressFilterController.addListener(() {
      if (!_inProgressFilterController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    // Defer .obs updates + fetch until after build — setting Rx in initState
    // while MainScreen's route Builder is still building triggers:
    // "setState() or markNeedsBuild() called during build" on Obx.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.mode == BookingScreenMode.shipments) {
        if (selectedTab == 1) {
          controller.getInProgressBookings();
        } else {
          controller.getConfirmedBookings();
        }
      } else if (widget.mode == BookingScreenMode.book &&
          (selectedTab == 1 || _isAdminUser)) {
        controller.getInProgressBookings();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _inProgressFilterController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (selectedTab == index) return;
    setState(() => selectedTab = index);
    _animController.forward(from: 0);
    if (widget.mode == BookingScreenMode.book) {
      if (index == 1) {
        _inProgressFilterController.index = 0;
        controller.getInProgressBookings();
      }
      return;
    }
    if (index == 1) {
      controller.getInProgressBookings();
    } else if (index == 0) {
      controller.getConfirmedBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBookMode = widget.mode == BookingScreenMode.book;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: CommonAppBar(
        title: isBookMode ? 'Saved Quotations' : 'My Shipments',
      ),
      body: Column(
        children: [
          if (!isBookMode) _buildTabBar(),
          Expanded(
            child:
                isBookMode
                    ? _buildSavedQuotesBody()
                    : Obx(() {
                      if (_isCurrentTabLoading()) return _buildShimmer();
                      return GetBuilder<BookingController>(
                        tag: controllerTag,
                        builder: (ctrl) {
                          if (selectedTab == 1) {
                            return _buildShipmentsInProgressPage(ctrl);
                          }

                          if (ctrl.filteredBookings.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildBookingList(
                            itemCount: ctrl.filteredBookings.length,
                            itemBuilder:
                                (index) => _buildBookedCard(
                                  ctrl.filteredBookings[index],
                                  ctrl,
                                ),
                          );
                        },
                      );
                    }),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedQuotesBody() {
    return Obx(() {
      if (_isCurrentTabLoading()) return _buildShimmer();
      return GetBuilder<BookingController>(
        tag: controllerTag,
        builder: (ctrl) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInProgressFilterTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _inProgressFilterController,
                  physics: const BouncingScrollPhysics(),
                  children:
                      _InProgressQuoteFilter.values
                          .map(
                            (filter) =>
                                _buildInProgressFilterPage(ctrl, filter),
                          )
                          .toList(),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildShipmentsInProgressPage(BookingController ctrl) {
    final acceptedList = _filteredShipmentsInProgressAccepted(ctrl);
    if (acceptedList.isEmpty) {
      return _buildInProgressEmptyState(_InProgressQuoteFilter.accepted);
    }
    return _buildBookingList(
      itemCount: acceptedList.length,
      itemBuilder: (index) => _buildQuotePriceCard(acceptedList[index], ctrl),
    );
  }

  List<Records> _filteredShipmentsInProgressAccepted(BookingController ctrl) {
    final filtered =
        ctrl.inProgressBookings.where((booking) {
          if (_isTestQuoteBooking(booking, ctrl)) return false;
          if (!_isRealInProgressQuote(booking, ctrl)) return false;
          return SavedQuotationsModel.isAcceptedStatus(
            _quoteStatus(booking, ctrl),
          );
        }).toList();
    return Records.sortNewestFirst(filtered);
  }

  bool _isRealInProgressQuote(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    if (id.isEmpty) return false;

    final seed = ctrl.inProgressAdminQuoteById[id];
    if (seed?.isTestQuoteData == true) return false;

    final quoteNo = _trimText(booking.quoteName ?? booking.orderNumber);
    if (SavedQuotationsModel.isTestQuoteLabel(
      quoteNo,
      opportunityName: booking.opportunityName?.toString(),
    )) {
      return false;
    }

    if (quoteNo.toLowerCase() == 'q-0000') return false;
    if (_isEmptyOpportunityShellQuote(booking, ctrl)) return false;
    if (!_hasResolvedRoute(booking, ctrl)) return false;
    return true;
  }

  bool _hasResolvedRoute(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final seed = ctrl.inProgressAdminQuoteById[id];
    final shipmentRecord = ctrl.inProgressShipmentRecordById[id];
    final pol = _trimText(
      booking.portOfLoadingC ??
          seed?.originPortR?.name ??
          shipmentRecord?.originPortName,
    );
    final pod = _trimText(
      booking.portOfDestinationC ??
          seed?.destinationPortR?.name ??
          shipmentRecord?.destinationPortName,
    );
    return pol.isNotEmpty && pod.isNotEmpty;
  }

  bool _isEmptyOpportunityShellQuote(Records booking, BookingController ctrl) {
    final quoteNo = _trimText(booking.quoteName ?? booking.orderNumber);
    return SavedQuotationsModel.isOpportunityShellQuoteName(quoteNo) &&
        !_hasResolvedRoute(booking, ctrl);
  }

  bool _isTestQuoteBooking(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final seed = ctrl.inProgressAdminQuoteById[id];
    if (seed?.isTestQuoteData == true) return true;
    final quoteNo = _trimText(booking.quoteName ?? booking.orderNumber);
    final opportunity = _trimText(booking.opportunityName);
    if (quoteNo.toLowerCase() == 'test quote') return true;
    return SavedQuotationsModel.isTestQuoteLabel(
      quoteNo,
      opportunityName:
          opportunity.isNotEmpty
              ? opportunity
              : booking.opportunityName?.toString(),
    );
  }

  Widget _buildBookingList({
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return AnimatedBuilder(
      animation: _animController,
      builder:
          (_, child) => FadeTransition(
            opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: _animController, curve: Curves.easeOut),
            ),
            child: child,
          ),
      child: ListView.builder(
        itemCount: itemCount,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemBuilder: (context, index) => itemBuilder(index),
      ),
    );
  }

  String _quoteStatus(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final seed = ctrl.inProgressAdminQuoteById[id];
    for (final raw in [
      booking.trackingStatusC,
      booking.customStatusC,
      seed?.status,
    ]) {
      final normalized = SavedQuotationsModel.normalizeQuoteListStatus(
        raw?.toString(),
      );
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  bool _isQuotationsTabQuote(Records booking, BookingController ctrl) {
    if (_isTestQuoteBooking(booking, ctrl)) return false;
    if (!_hasResolvedRoute(booking, ctrl)) return false;
    return SavedQuotationsModel.isQuotationsTabStatus(
      _quoteStatus(booking, ctrl),
    );
  }

  List<Records> _filteredInProgressBookings(
    BookingController ctrl,
    _InProgressQuoteFilter filter,
  ) {
    final filtered =
        ctrl.inProgressBookings.where((booking) {
          if (!_isQuotationsTabQuote(booking, ctrl)) return false;
          if (filter != _InProgressQuoteFilter.accepted &&
              _isEmptyOpportunityShellQuote(booking, ctrl)) {
            return false;
          }
          final status = _quoteStatus(booking, ctrl);
          switch (filter) {
            case _InProgressQuoteFilter.all:
              return SavedQuotationsModel.isQuotationsTabStatus(status);
            case _InProgressQuoteFilter.draft:
              if (!_isRealInProgressQuote(booking, ctrl)) return false;
              return SavedQuotationsModel.isDraftStatus(status);
            case _InProgressQuoteFilter.accepted:
              return SavedQuotationsModel.isAcceptedStatus(status);
          }
        }).toList();
    return Records.sortNewestFirst(filtered);
  }

  Widget _buildInProgressFilterPage(
    BookingController ctrl,
    _InProgressQuoteFilter filter,
  ) {
    final inProgressList = _filteredInProgressBookings(ctrl, filter);
    if (inProgressList.isEmpty) {
      return _buildInProgressEmptyState(filter);
    }
    return _buildBookingList(
      itemCount: inProgressList.length,
      itemBuilder:
          (index) => _buildQuotationsTabCard(inProgressList[index], ctrl),
    );
  }

  Widget _buildQuotationsTabCard(Records booking, BookingController ctrl) {
    return _buildQuotePriceCard(booking, ctrl);
  }

  Widget _buildQuotePriceCard(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final adminSeed = ctrl.inProgressAdminQuoteById[id];
    final shipmentRecord = ctrl.inProgressShipmentRecordById[id];
    final pol = _trimText(
      booking.portOfLoadingC ??
          adminSeed?.originPortR?.name ??
          shipmentRecord?.originPortName,
    );
    final pod = _trimText(
      booking.portOfDestinationC ??
          adminSeed?.destinationPortR?.name ??
          shipmentRecord?.destinationPortName,
    );
    final size = _quoteSizeLabel(booking, ctrl);
    final validTill = _quoteValidTill(booking, ctrl);
    final price = _quotePriceLabel(booking, ctrl);
    final status = _quoteStatus(booking, ctrl);
    final route = [
      if (pol.isNotEmpty) pol,
      if (pod.isNotEmpty) pod,
    ].join('  →  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openInProgressDetail(id, ctrl),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _navyLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: _navy,
                          size: 22,
                        ),
                      ),
                      if (size.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          size,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                route.isEmpty ? 'Quotation' : route,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _quoteStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Valid till',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF98A2B3),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    validTill.isEmpty ? '—' : validTill,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'All-in Rate',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF98A2B3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  price,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _quoteSizeLabel(Records booking, BookingController ctrl) {
    final raw = _quoteContainerSize(booking, ctrl);
    final feet = RegExp(r'(20|40|45)').firstMatch(raw);
    if (feet != null) return "${feet.group(1)}'";
    return raw == '—' ? '' : raw;
  }

  String _quoteValidTill(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final seed = ctrl.inProgressAdminQuoteById[id];
    final shipment = ctrl.inProgressShipmentRecordById[id];
    for (final raw in [
      booking.expirationDate,
      seed?.expirationDate,
      shipment?.expirationDate,
    ]) {
      final formatted = Records.formatListDate(raw);
      if (formatted != null) return formatted;
    }
    return '';
  }

  String _quotePriceLabel(Records booking, BookingController ctrl) {
    if (booking.displayAmount != '—') return booking.displayAmount;
    final id = booking.id?.toString().trim() ?? '';
    final seed = ctrl.inProgressAdminQuoteById[id];
    final price = seed?.totalPrice;
    if (price != null) {
      final currency = seed?.currencyIsoCode?.trim() ?? '';
      final text =
          price == price.roundToDouble()
              ? price.round().toString()
              : price.toString();
      return currency.isEmpty ? text : '$currency $text';
    }
    final grand = ctrl.inProgressShipmentRecordById[id]?.grandTotal;
    if (grand != null && grand.toString().trim().isNotEmpty) {
      return grand.toString();
    }
    return '—';
  }

  Widget _quoteStatusBadge(String status) {
    final String label;
    final Color background;
    final Color foreground;
    if (SavedQuotationsModel.isAcceptedStatus(status)) {
      label = 'Accepted';
      background = _greenBg;
      foreground = _greenText;
    } else if (SavedQuotationsModel.isPendingStatus(status)) {
      label = 'Pending';
      background = const Color(0xFFFFF4E5);
      foreground = const Color(0xFFB45309);
    } else if (SavedQuotationsModel.isDraftStatus(status)) {
      label = 'Draft';
      background = const Color(0xFFE8F0FE);
      foreground = const Color(0xFF1D4ED8);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  void _navigateToSearchRates() {
    Get.offAll(() => const MainScreen(initialTab: 1));
  }

  void _navigateToShipmentsTab() {
    Get.offAll(() => const MainScreen(initialTab: 3, initialShipmentsTab: 1));
  }

  // ── Tab bar ──────────────────────────────────────────────

  Widget _buildTabBar() {
    if (widget.mode == BookingScreenMode.book) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Row(
        children: [
          _tabItem(
            index: 0,
            icon: Icons.inventory_2_outlined,
            label: 'Booked',
            showIcon: true,
          ),
          _tabItem(
            index: 1,
            icon: Icons.access_time_rounded,
            label: 'In Progress',
            showIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _tabItem({
    required int index,
    required IconData icon,
    required String label,
    bool showIcon = true,
    bool compact = false,
  }) {
    final active = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: active ? _navy : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 10 : 11),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  icon,
                  size: compact ? 19 : 20,
                  color: active ? Colors.white : const Color(0xFF9CA3AF),
                ),
                SizedBox(height: compact ? 4 : 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 14 : 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressFilterTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Row(
        children:
            _InProgressQuoteFilter.values.map((filter) {
              final index = filter.index;
              final active = _inProgressFilterController.index == index;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _inProgressFilterController.animateTo(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: active ? _navy : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        switch (filter) {
                          _InProgressQuoteFilter.all => 'All',
                          _InProgressQuoteFilter.draft => 'Draft',
                          _InProgressQuoteFilter.accepted => 'Accepted',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? Colors.white : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // ── Booked card ──────────────────────────────────────────

  Widget _buildBookedCard(Records booking, BookingController ctrl) {
    final orderId = booking.id?.toString().trim() ?? '';
    final opening = _openingOrderId == orderId && orderId.isNotEmpty;
    final pol = booking.portOfLoadingC?.toString().trim() ?? '';
    final pod = booking.portOfDestinationC?.toString().trim() ?? '';
    final status = booking.trackingStatusC?.toString().trim() ?? '';
    final orderNo = booking.displayOrderNumber;
    final bl = booking.blNumberC?.toString().trim() ?? '';
    final containerType = booking.containerTypeC?.toString().trim() ?? '';
    final bookedDate = Records.formatListDate(booking.bookedDateC) ??
        (booking.displayBookedDate.isEmpty ? null : booking.displayBookedDate);
    final spec = _containerSpec(booking);
    final vessel = booking.vesselNameC?.toString().trim() ?? '';
    final voyage = booking.voyageNumberC?.toString().trim() ?? '';
    final loadType = booking.leadTypeC?.toString().trim() ?? '';
    final commodity = booking.commodityC?.toString().trim() ?? '';
    final routing = booking.routingC?.toString().trim() ?? '';
    final mode = booking.modeOfShipmentC?.toString().trim() ?? '';
    final ocean = _isOceanMode(mode, loadType);
    final arrival = Records.formatListDate(booking.arrivalDateC);
    final route = [if (pol.isNotEmpty) pol, if (pod.isNotEmpty) pod];
    final vesselLine = [
      if (vessel.isNotEmpty) 'Vessel: $vessel',
      if (voyage.isNotEmpty) 'Voyage: $voyage',
    ].join('  •  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: opening ? null : () => _openBookedDetail(booking, ctrl),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _navyLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _navyLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _bookedCardIcon(booking),
                          color: _navy,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.isEmpty ? 'Shipment' : route.join('  →  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                            ),
                            if (orderNo.isNotEmpty) _cardDetail('Order: $orderNo'),
                            if (bl.isNotEmpty) _cardDetail('BL: $bl'),
                            if (containerType.isNotEmpty)
                              _cardDetail('Container type: $containerType'),
                            if (bookedDate != null)
                              _cardDetail('Booked date: $bookedDate'),
                            if (spec.isNotEmpty) _cardDetail('Container size: $spec'),
                            if (vesselLine.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  vesselLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF667085),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            if (loadType.isNotEmpty)
                              _cardDetail('Load type: $loadType'),
                            if (ocean && routing.isNotEmpty)
                              _cardDetail('Routing: $routing'),
                            if (ocean && commodity.isNotEmpty)
                              _cardDetail('Commodity: $commodity'),
                            if (!ocean && commodity.isNotEmpty)
                              _cardDetail('Commodity: $commodity'),
                            if (arrival != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'ETA: $arrival',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      opening
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardDetail(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF667085),
          height: 1.3,
        ),
      ),
    );
  }

  bool _isOceanMode(String mode, String loadType) {
    final value = '${mode.toLowerCase()} ${loadType.toLowerCase()}';
    if (value.contains('air')) return false;
    return true;
  }

  String _containerSpec(Records booking) {
    final qty = booking.containerQuantityC?.toString().trim() ?? '';
    final size = booking.containerSizeC?.toString().trim() ?? '';
    final type = booking.containerTypeC?.toString().trim() ?? '';
    final feet = RegExp(r'(20|40|45)').firstMatch('$size $type');
    if (feet == null) return '';
    final shortType = _shortContainerType(type);
    final sizeLabel =
        shortType.isEmpty ? "${feet.group(1)}'" : "${feet.group(1)}' $shortType";
    final count = num.tryParse(qty);
    if (count != null && count > 0) {
      final shown =
          count == count.roundToDouble() ? count.round().toString() : qty;
      return '$shown x $sizeLabel';
    }
    return sizeLabel;
  }

  String _shortContainerType(String type) {
    final lower = type.toLowerCase();
    if (lower.isEmpty) return '';
    if (lower.contains('high cube') || lower.contains('hc')) return 'HC';
    if (lower.contains('reefer') || lower.contains('rf')) return 'RF';
    if (lower.contains('open top')) return 'OT';
    if (lower.contains('flat')) return 'FR';
    if (RegExp(r"^[a-z]{2,3}$", caseSensitive: false).hasMatch(type.trim())) {
      return type.trim().toUpperCase();
    }
    return '';
  }

  IconData _bookedCardIcon(Records booking) {
    final mode = booking.modeOfShipmentC?.toString().toLowerCase() ?? '';
    final load = booking.leadTypeC?.toString().toLowerCase() ?? '';
    if (mode.contains('air') || load == 'air') return Icons.flight_rounded;
    return Icons.directions_boat_filled;
  }

  Future<void> _openBookedDetail(
    Records booking,
    BookingController ctrl,
  ) async {
    final orderId = booking.id?.toString().trim() ?? '';
    if (_openingOrderId != null) return;
    setState(() => _openingOrderId = orderId);
    try {
      await ctrl.fetchBookingDetails(
        quoteId: booking.quoteId ?? '',
        orderId: orderId,
      );
      if (!mounted) return;

      ApiProvider.debugLogOrderDocuments(
        orderId: orderId,
        documents: ctrl.orderDocuments,
        source: 'Booked card',
      );

      final detail = <String, dynamic>{};
      if (ctrl.bookingDetailData is Map) {
        detail.addAll(Map<String, dynamic>.from(ctrl.bookingDetailData as Map));
      }
      void fill(String key, dynamic value) {
        final existing = detail[key];
        final empty = existing == null || existing.toString().trim().isEmpty;
        if (empty && value != null && value.toString().trim().isNotEmpty) {
          detail[key] = value;
        }
      }

      for (final entry in booking.toJson().entries) {
        fill(entry.key, entry.value);
      }
      fill('Container_Size__c', booking.containerSizeC);
      fill('Container_Type__c', booking.containerTypeC);
      fill('Mode_of_Shipment__c', booking.modeOfShipmentC);
      fill('Lead_Type__c', booking.leadTypeC);
      fill('Account_Name', booking.accountName);

      await Get.to(
        () => const BookingDetailScreen(),
        arguments: {'orderId': orderId, 'detailData': detail},
      );
      if (!mounted) return;
      setState(() => selectedTab = 0);
      controller.getConfirmedBookings();
    } finally {
      if (mounted) setState(() => _openingOrderId = null);
    }
  }

  // ── In-progress / quotation card ─────────────────────────

  String _trimText(dynamic value) => value?.toString().trim() ?? '';


  String _quoteContainerSize(Records booking, BookingController ctrl) {
    final id = booking.id?.toString().trim() ?? '';
    final adminSeed = ctrl.inProgressAdminQuoteById[id];
    final shipmentRecord = ctrl.inProgressShipmentRecordById[id];
    return _trimText(
      booking.containerSizeC ??
          adminSeed?.containerSize ??
          shipmentRecord?.containerSizeC,
    );
  }


  void _openInProgressDetail(String id, BookingController ctrl) {
    if (id.isEmpty) return;

    final adminSeed = ctrl.inProgressAdminQuoteById[id];
    final shipmentRecord = ctrl.inProgressShipmentRecordById[id];

    if (adminSeed != null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder:
              (_) => QuoteCardDetailScreen(
                quote: adminSeed,
                shipmentRecord: shipmentRecord,
              ),
        ),
      );
      return;
    }

    if (shipmentRecord != null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => QuoteCardDetailScreen.fromShipment(shipmentRecord),
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemBuilder:
          (_, __) => Shimmer.fromColors(
            baseColor: const Color(0xFFE9EDF2),
            highlightColor: const Color(0xFFF5F7FA),
            child: Container(
              margin: const EdgeInsets.only(bottom: 13),
              height: 248,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _navyLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: _navy,
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              children: [
                const TextSpan(
                  text: "Your shipment lane looks a little too quiet. ",
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: _navigateToSearchRates,
                    child: const Text(
                      "Book now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _navy,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: "."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressEmptyState(_InProgressQuoteFilter filter) {
    late final String message;
    late final String actionLabel;
    late final VoidCallback onAction;

    switch (filter) {
      case _InProgressQuoteFilter.all:
        message = 'No Quotations';
        actionLabel = 'Ship rates';
        onAction = _navigateToSearchRates;
        break;
      case _InProgressQuoteFilter.draft:
        message = 'No Quotes Placed';
        actionLabel = 'Place Quote';
        onAction = _navigateToSearchRates;
        break;
      case _InProgressQuoteFilter.accepted:
        message = 'No Quotes Accepted';
        actionLabel = 'Reserve Your Space';
        onAction = _navigateToShipmentsTab;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _navyLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 32,
                color: _navy,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
