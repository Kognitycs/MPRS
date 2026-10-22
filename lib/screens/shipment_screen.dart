import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/data_response.dart';
import 'package:mprs_android/core/constants/base_client.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/service/booking_service.dart';
import 'package:mprs_android/model/get_shipment_model.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/screens/home_screen/search_routes_screen.dart';
import 'package:mprs_android/screens/quote/quote_card_detail_screen.dart';
import 'package:mprs_android/screens/support_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';

import '../model/common/Booking_success.dart';

class ShipmentScreen extends StatefulWidget {
  const ShipmentScreen({super.key});

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  final TextEditingController searchController = TextEditingController();

  // Used to force FutureBuilder to re-fetch after booking
  int _refreshKey = 0;

  /// Admin shipments: full quote models keyed by id (for detail screen).
  final Map<String, SavedQuotationsModel> _adminQuoteById = {};

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _refreshShipments(String type) async {
    setState(() => _refreshKey++);
    await (type == 'Import'
        ? getShipmentImportData()
        : getShipmentExportData());
  }

  void _navigateToSearchRates() {
    Get.key.currentState?.push(
      MaterialPageRoute(builder: (_) => const SearchRouteScreen()),
    );
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  DateTime? _recordSortDate(Records record) {
    final id = record.id?.toString().trim() ?? '';
    final adminSeed = _adminQuoteById[id];

    for (final raw in [
      adminSeed?.createdDateC,
      record.createdDate,
      record.expirationDate,
      record.bookedDateC,
    ]) {
      if (raw == null || raw.toString().trim().isEmpty) continue;
      final text = raw.toString().trim();
      final parsed = DateTime.tryParse(text.split('T').first) ??
          DateTime.tryParse(text);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<Records> _sortRecordsNewestFirst(List<Records> records) {
    final sorted = List<Records>.from(records);
    sorted.sort((a, b) {
      final da = _recordSortDate(a);
      final db = _recordSortDate(b);
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return (b.id?.toString() ?? '').compareTo(a.id?.toString() ?? '');
    });
    return sorted;
  }

  bool _isTestShipmentRecord(Records item) {
    final id = item.id?.toString().trim() ?? '';
    final seed = _adminQuoteById[id];
    if (seed != null && seed.isTestQuoteData) return true;
    return SavedQuotationsModel.isTestQuoteLabel(
      item.name?.toString(),
      opportunityName:
          item.opportunity?.name?.toString() ?? seed?.opportunityName,
    );
  }

  /// Live filter: quote name (QT-…) or opportunity (MSL…).
  bool _matchesSearchQuery(Records item, String query) {
    if (query.isEmpty) return true;

    final id = item.id?.toString().trim() ?? '';
    final seed = _adminQuoteById[id];

    final quoteNo = (item.name ?? seed?.name ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final opportunity = (item.opportunity?.name ?? seed?.opportunityName ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final orderNo = (item.orderNumber ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return quoteNo.contains(query) ||
        opportunity.contains(query) ||
        orderNo.contains(query);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // API CALLS
  // --------------------------------------------------------------------------

  Future<void> bookQuote({
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
    if (mounted) {
      _refresh();
    }
  }

  Future<DataResponse<GetShipmentModel?>> getShipmentImportData() async {
    if (AuthDataHelper.isAdminUser()) {
      return _fetchAdminShipments(importTab: true);
    }

    final accountId = BookingService.resolveAccountId();
    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getBookingRequestReceived(accountId),
      method: DioMethod.get,
    );

    try {
      var response = await BaseClient().handleRequest(apiRequest);
      final dataResponse = DataResponse<GetShipmentModel?>.fromJson(
        response,
        (json) => GetShipmentModel.fromJson(json),
      );
      return dataResponse;
    } catch (e) {
      return DataResponse(message: e.toString(), success: false);
    }
  }

  Future<DataResponse<GetShipmentModel?>> getShipmentExportData() async {
    if (AuthDataHelper.isAdminUser()) {
      return _fetchAdminShipments(importTab: false);
    }

    final accountId = BookingService.resolveAccountId();
    ApiRequest apiRequest = ApiRequest(
      url: ApiConstants.getBookingSentToCustomer(accountId),
      method: DioMethod.get,
    );

    try {
      var response = await BaseClient().handleRequest(apiRequest);
      final dataResponse = DataResponse<GetShipmentModel?>.fromJson(
        response,
        (json) => GetShipmentModel.fromJson(json),
      );
      return dataResponse;
    } catch (e) {
      return DataResponse(message: e.toString(), success: false);
    }
  }

  /// Admin: all users — quotations from app opportunities (`opp_from_rms_app`).
  Future<DataResponse<GetShipmentModel?>> _fetchAdminShipments({
    required bool importTab,
  }) async {
    try {
      final filtered = (await ApiProvider().fetchAdminAppCreatedQuotations())
          .where((q) => !q.isTestQuoteData)
          .toList();

      if (filtered.isEmpty) {
        return DataResponse(
          success: true,
          code: 200,
          message: 'No app-created quotations found',
          body: GetShipmentModel(status: 200, records: []),
        );
      }

      _adminQuoteById
        ..clear()
        ..addEntries(
          filtered
              .where((q) => q.id != null && q.id!.trim().isNotEmpty)
              .map((q) => MapEntry(q.id!.trim(), q)),
        );

      debugPrint(
        '📦 Admin shipments ${importTab ? "Import" : "Export"} tab: '
        '${filtered.length} app-created quotation(s) (all users, RMS opportunity)',
      );
      for (var i = 0; i < filtered.length && i < 20; i++) {
        final q = filtered[i];
        debugPrint(
          '   quote[$i] id=${q.id} name=${q.name} status=${q.status} '
          'rms=${q.opportunityFromRms} account=${q.accountName ?? "—"}',
        );
      }
      if (filtered.length > 20) {
        debugPrint('   ... +${filtered.length - 20} more');
      }

      final records = SavedQuotationsModel.sortNewestFirst(filtered)
          .map((q) => Records.fromJson(q.toShipmentRecordJson()))
          .toList();

      return DataResponse(
        success: true,
        code: 200,
        body: GetShipmentModel(status: 200, records: records),
      );
    } catch (e) {
      debugPrint('❌ Admin shipments error: $e');
      return DataResponse(message: e.toString(), success: false, body: null);
    }
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: const CommonAppBar(title: "My Shipments"),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),

              _buildInfoBanner(),

              const SizedBox(height: 14),

              _buildSearchBar(),

              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildShipmentList("Import"),
                    _buildShipmentList("Export"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // INFO BANNER
  // --------------------------------------------------------------------------

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: AppColors.main),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Showing active quotations that are ready for booking.",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SEARCH BAR
  // --------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: TextField(
        controller: searchController,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by QT, order, or MSL opportunity',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SHIPMENT LIST
  // --------------------------------------------------------------------------

  Widget _buildShipmentList(String type) {
    return FutureBuilder<DataResponse<GetShipmentModel?>>(
      key: ValueKey("$type-$_refreshKey"),

      future: type == "Import"
          ? getShipmentImportData()
          : getShipmentExportData(),

      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.main,
            ),
          );
        }

        final isError = snapshot.hasError || snapshot.data?.success == false;
        final shipmentModel = snapshot.data?.body;

        final List<Records> items = (shipmentModel?.records ?? [])
            .whereType<Records>()
            .where((item) => !_isTestShipmentRecord(item))
            .toList();

        final query = searchController.text.trim().toLowerCase();
        final filteredItems = _sortRecordsNewestFirst(
          items.where((item) => _matchesSearchQuery(item, query)).toList(),
        );

        if (isError) {
          return RefreshIndicator(
            color: AppColors.main,
            onRefresh: () => _refreshShipments(type),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    message: snapshot.data?.message ?? 'Something went wrong',
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredItems.isEmpty) {
          return RefreshIndicator(
            color: AppColors.main,
            onRefresh: () => _refreshShipments(type),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    message: query.isEmpty
                        ? 'Your shipment lane looks a little too quite.'
                        : 'No quote or opportunity matches your search',
                    showGetQuoteLink: query.isEmpty,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.main,
          onRefresh: () => _refreshShipments(type),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return _buildShipmentCard(record: item);
            },
          ),
        );
      },
    );
  }
  // --------------------------------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------------------------------

  Widget _buildEmptyState({
    String message = 'No booking available',
    bool showGetQuoteLink = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade50,
              ),
              child: const Center(
                child: Icon(
                  Icons.file_copy_rounded,
                  color: Colors.blue,
                  size: 35,
                ),
              ),
            ),
            const SizedBox(height: 26),
            if (showGetQuoteLink) ...[
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _navigateToSearchRates,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Book Now',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.main,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ] else
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CARD
  // --------------------------------------------------------------------------

  Widget _buildShipmentCard({required Records record}) {
    final quoteId = record.id?.toString() ?? "";
    final quoteNo = record.name?.toString() ?? "Q-0000";
    final opportunity =
        record.opportunity?.name?.toString() ?? "Opportunity Name";
    final account = record.account?.name?.toString() ?? "Account Name";
    final amount = _formatAmount(record.grandTotal);
    final status = record.status?.toString() ?? "Draft";
    final expiryDate = _formatExpiry(record.expirationDate);
    final loadType = record.leadTypeC?.toString() ?? "";
    final bool isPresented = status.toLowerCase() == "presented";

    return GestureDetector(
      onTap: () {
        final seed = _adminQuoteById[quoteId.trim()];
        if (seed != null) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => QuoteCardDetailScreen(
                quote: seed,
                shipmentRecord: record,
              ),
            ),
          );
        } else {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => QuoteCardDetailScreen.fromShipment(record),
            ),
          );
        }
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.main,
            ),
          ),

          const SizedBox(width: 12),

          // DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quoteNo,
                  style: const TextStyle(
                    color: AppColors.main,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  opportunity,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  account,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                if (loadType.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    loadType,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    Text(
                      "\$$amount",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPresented
                            ? Colors.blue.shade50
                            : AppColors.accentLight,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isPresented ? Colors.blue : AppColors.main,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // RIGHT SIDE
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                expiryDate,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 18),

              if (!AuthDataHelper.isAdminUser())
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      _showBookingDialog(quoteId: quoteId);
                    },
                    child: const Text(
                      "Book Now",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0';
    final num? parsed = value is num
        ? value
        : num.tryParse(value.toString().replaceAll(',', ''));
    if (parsed == null) return value.toString();
    return NumberFormat('#,##0').format(parsed);
  }

  String _formatExpiry(dynamic raw) {
    if (raw == null) return 'N/A';
    final text = raw.toString();
    if (text.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(text.split('T').first);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return text;
    }
  }

  // --------------------------------------------------------------------------
  // BOOKING DIALOG
  // --------------------------------------------------------------------------

  void _showBookingDialog({required String quoteId}) {
    showDialog(
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
                  "Confirm Your Booking",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "You’re now Genie-Fied.",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                const Text(
                  "By continuing, you authorize MPRS to: ",
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
                              "Confirm the quoted commercial terms",
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
                              "Create your shipment order request",
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
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Need help? Speak with your Account Manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: AppColors.main,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (!AuthDataHelper.isAdminUser())
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
                            await bookQuote(
                              quoteId: quoteId,
                              dialogContext: dialogContext,
                            );
                          },
                          child: const Text(
                            "Reserve Your Space",
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
                        onPressed: () => Get.back(),
                        child: const Text(
                          "Cancel",
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
                    onPressed: () => Get.back(),
                    child: const Text(
                      "Close",
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
}