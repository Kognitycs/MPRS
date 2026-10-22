import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/auth_data_helper.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/api_provider.dart';
import '../core/constants/base_client.dart';
import '../core/constants/db_helper.dart';
import '../model/booking_detail_model.dart';
import 'package:mprs_android/service/notification/shipment_status_notification_service.dart';
import 'package:mprs_android/service/reserved_quote_store.dart';
import '../model/get_booking_list_model_new.dart';
import '../model/get_shipment_model.dart' as shipment;
import '../model/order_document_model.dart';
import '../model/saved_quotations_model.dart';
import 'saved_quotations_controller.dart';

class BookingController extends GetxController {
  /// Booked / confirmed shipments tab.
  RxBool isBookedLoading = false.obs;

  /// In Progress tab and Saved Quotations (quotations) tab.
  RxBool isInProgressLoading = false.obs;

  /// Booking detail screen fetch only.
  RxBool isLoading = false.obs;

  String errorMessage = '';
  String selectedFilter = 'All';
  String lastSearchQuery = '';

  /// True when the booked-shipments request failed (home can fall back to sample stats).
  bool confirmedLoadFailed = false;

  /// True when the in-progress shipments request failed.
  bool inProgressLoadFailed = false;

  List<Records> allBookings = [];
  List<Records> filteredBookings = [];

  /// Orders whose CreatedDate is today. Empty until [loadTodayBookings] finishes.
  List<Records> todayBookings = [];
  bool todayBookingsReady = false;
  Future<void> _fillBookedCargoFromQuotes(List<Records> bookings) async {
    if (bookings.isEmpty) return;
    try {
      if (!Get.isRegistered<SavedQuotationsController>()) {
        Get.put(SavedQuotationsController());
      }
      final quotes = Get.find<SavedQuotationsController>();
      if (quotes.quotesList.isEmpty) {
        await quotes.fetchSavedQuotes();
      }
      final byId = <String, SavedQuotationsModel>{
        for (final quote in quotes.quotesList)
          if ((quote.id ?? '').trim().isNotEmpty) quote.id!.trim(): quote,
      };
      for (final booking in bookings) {
        _applyQuoteCargo(
          booking,
          _matchQuote(booking, byId, quotes.quotesList),
        );
      }
      for (final booking in bookings) {
        final quoteId = booking.quoteId?.toString().trim() ?? '';
        final needsCargo =
            _blank(booking.containerSizeC) ||
            _blank(booking.commodityC) ||
            _blank(booking.routingC);
        if (quoteId.isEmpty || !needsCargo) continue;
        try {
          final response = await BaseClient().handleRequest(
            ApiRequest(
              url: ApiConstants.getQuoteContainerFieldsById(quoteId),
              method: DioMethod.get,
            ),
          );
          final parsed = _quoteFromGetData(response);
          if (parsed != null) _applyQuoteCargo(booking, parsed);
        } catch (e) {
          debugPrint('Quote cargo lookup skipped for $quoteId: $e');
        }
      }
    } catch (e) {
      debugPrint('Quote cargo enrich skipped: $e');
    }
  }

  SavedQuotationsModel? _matchQuote(
    Records booking,
    Map<String, SavedQuotationsModel> byId,
    List<SavedQuotationsModel> quotes,
  ) {
    final id = booking.quoteId?.toString().trim() ?? '';
    if (id.isNotEmpty && byId.containsKey(id)) return byId[id];
    final opp = booking.opportunityName?.toString().trim().toLowerCase() ?? '';
    if (opp.isEmpty) return null;
    final hits =
        quotes
            .where(
              (quote) =>
                  (quote.opportunityName ?? '').trim().toLowerCase() == opp,
            )
            .toList();
    if (hits.length == 1) return hits.first;
    return null;
  }

  void _applyQuoteCargo(Records booking, SavedQuotationsModel? quote) {
    if (quote == null) return;
    booking.leadTypeC = _keepOr(booking.leadTypeC, quote.loadType);
    booking.containerTypeC = _keepOr(
      booking.containerTypeC,
      quote.containerType,
    );
    booking.containerSizeC = _keepOr(
      booking.containerSizeC,
      quote.containerSize,
    );
    booking.modeOfShipmentC = _keepOr(
      booking.modeOfShipmentC,
      quote.modeOfShipment,
    );
    booking.commodityC = _keepOr(booking.commodityC, quote.commodity);
    booking.grossWeightC = _keepOr(
      booking.grossWeightC,
      quote.grossWeight?.toString(),
    );
    if ((booking.quoteId?.toString().trim() ?? '').isEmpty &&
        (quote.id ?? '').trim().isNotEmpty) {
      booking.quoteId = quote.id;
    }
  }

  SavedQuotationsModel? _quoteFromGetData(dynamic response) {
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    for (final key in ['records', 'data', 'items', 'body']) {
      final value = map[key];
      if (value is List && value.isNotEmpty && value.first is Map) {
        return SavedQuotationsModel.fromJson(
          Map<String, dynamic>.from(value.first as Map),
        );
      }
      if (value is Map) {
        final nested = _quoteFromGetData(value);
        if (nested != null) return nested;
      }
    }
    if (map['Id'] != null || map['Container_Size__c'] != null) {
      return SavedQuotationsModel.fromJson(map);
    }
    return null;
  }

  bool _blank(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null';
  }

  dynamic _keepOr(dynamic current, String? next) {
    final text = current?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return current;
    final incoming = next?.trim() ?? '';
    if (incoming.isEmpty) return current;
    return incoming;
  }

  Future<void> getConfirmedBookings({bool accountScoped = false}) async {
    isBookedLoading.value = true;
    confirmedLoadFailed = false;
    // Clear immediately so a previous user's bookings are never briefly shown.
    allBookings.clear();
    filteredBookings.clear();
    update();

    try {
      if (AuthDataHelper.isAdminUser() && !accountScoped) {
        final list = Records.sortNewestFirst(
          await ApiProvider().fetchAdminRmsBookedOrders(),
        );
        await _fillBookedCargoFromQuotes(list);
        filteredBookings
          ..clear()
          ..addAll(list);
        allBookings
          ..clear()
          ..addAll(list);
        await _appendReservedQuotes();
        allBookings = Records.sortNewestFirst(allBookings);
        filteredBookings = Records.sortNewestFirst(filteredBookings);
        confirmedLoadFailed = false;
        _mergeTodayWithLoaded();
        update();
        return;
      }

      // Prefer DbHelper; fall back to the separately stored AuthDataHelper key.
      final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
      final accountId =
          fromDb.isNotEmpty ? fromDb : AuthDataHelper.getAccountId().trim();
      if (accountId.isEmpty) {
        confirmedLoadFailed = true;
        return;
      }

      final apiRequest = ApiRequest(
        url: ApiConstants.userBookingsList(accountId),
        method: DioMethod.get,
      );

      final response = await BaseClient().handleRequest(apiRequest);

      debugPrint('BOOKING RESPONSE : $response');

      if (response != null && response['status'] == 200) {
        filteredBookings.clear();
        allBookings.clear();

        for (var item in response['bookings']) {
          final booking = Records.fromJson(item);
          filteredBookings.add(booking);
          allBookings.add(booking);
        }
        await _fillBookedCargoFromQuotes(allBookings);
        await _appendReservedQuotes();
        allBookings = Records.sortNewestFirst(allBookings);
        filteredBookings = Records.sortNewestFirst(filteredBookings);

        // New status alerts only (not when opening Notifications / login).
        await ShipmentStatusNotificationService.processBookingRecords(
          allBookings,
        );
        confirmedLoadFailed = false;
        _mergeTodayWithLoaded();
        update();
      } else {
        await _appendReservedQuotes();
        confirmedLoadFailed = allBookings.isEmpty;
      }
    } catch (e) {
      debugPrint('ERROR : $e');
      try {
        await _appendReservedQuotes();
      } catch (appendError) {
        debugPrint('ERROR appending reserved quotes: $appendError');
      }
      confirmedLoadFailed = allBookings.isEmpty;
    } finally {
      isBookedLoading.value = false;
      update();
    }
  }

  /// Loads orders created today. External and internal users are limited to
  /// their account. Admin sees every account.
  Future<void> loadTodayBookings() async {
    try {
      final isAdmin = AuthDataHelper.isAdminUser();
      final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
      final accountId =
          fromDb.isNotEmpty ? fromDb : AuthDataHelper.getAccountId().trim();
      final response = await BaseClient().handleRequest(
        ApiRequest(
          url: ApiConstants.ordersCreatedToday(
            accountId: isAdmin ? null : accountId,
          ),
          method: DioMethod.get,
        ),
      );
      final rows = _salesforceRecords(response);
      if (rows == null) {
        todayBookingsReady = false;
        return;
      }
      final parsed = <Records>[];
      for (final item in rows) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final onRow = map['AccountId']?.toString().trim() ?? '';
        if (!isAdmin &&
            accountId.isNotEmpty &&
            onRow.isNotEmpty &&
            onRow != accountId) {
          continue;
        }
        final record = Records.fromJson(map);
        final id = record.id?.toString().trim() ?? '';
        if (!id.startsWith('801')) continue;
        parsed.add(record);
      }
      todayBookings = Records.sortNewestFirst(parsed);
      _mergeTodayWithLoaded();
      todayBookingsReady = true;
    } catch (e) {
      todayBookingsReady = false;
      debugPrint('Today bookings failed: $e');
    } finally {
      update();
    }
  }

  void _mergeTodayWithLoaded() {
    if (todayBookings.isEmpty || allBookings.isEmpty) return;
    final byId = <String, Records>{
      for (final booking in allBookings)
        if ((booking.id?.toString().trim() ?? '').isNotEmpty)
          booking.id.toString().trim(): booking,
    };
    todayBookings = [
      for (final order in todayBookings)
        _preferLoadedOrder(order, byId[order.id?.toString().trim() ?? '']),
    ];
  }

  Records _preferLoadedOrder(Records today, Records? loaded) {
    if (loaded == null) return today;
    final created = loaded.createdDate?.toString().trim() ?? '';
    if (created.isEmpty || created == 'null') {
      loaded.createdDate = today.createdDate;
    }
    return loaded;
  }

  List<dynamic>? _salesforceRecords(dynamic response) {
    if (response is String) {
      try {
        return _salesforceRecords(jsonDecode(response));
      } catch (_) {
        return null;
      }
    }
    if (response is List) return response;
    if (response is! Map) return null;
    final status = response['status'];
    if (status is num && status >= 400) return null;
    if (response['success'] == false && response['records'] == null) {
      return null;
    }
    for (final key in ['records', 'data', 'body', 'result']) {
      final value = response[key];
      if (value is List) return value;
      if (value is String) {
        final decoded = _salesforceRecords(value);
        if (decoded != null) return decoded;
      }
      if (value is Map) {
        final nested = _salesforceRecords(value);
        if (nested != null) return nested;
      }
    }
    if (response['totalSize'] != null) return const [];
    return null;
  }

  Future<void> _appendReservedQuotes() async {
    final accountId =
        AuthDataHelper.getAccountId().trim().isNotEmpty
            ? AuthDataHelper.getAccountId().trim()
            : (DbHelper().getUserModel()?.accountId?.trim() ?? '');
    if (accountId.isEmpty) return;

    final bookedIds = <String>{
      for (final booking in allBookings)
        if ((booking.quoteId?.toString().trim() ?? '').isNotEmpty)
          booking.quoteId.toString().trim(),
    };
    await ReservedQuoteStore.removeAll(bookedIds);
    final extra = await ApiProvider().reservedQuotesNotYetBooked(
      accountId: accountId,
      reservedIds: ReservedQuoteStore.ids(),
      bookedQuoteIds: bookedIds,
    );
    if (extra.isEmpty) return;
    allBookings.addAll(extra);
    filteredBookings.addAll(extra);
  }

  void setFilter(String status) {
    selectedFilter = status;
    applyFilters(lastSearchQuery);
  }

  void applyFilters(String query) {
    lastSearchQuery = query.toLowerCase();

    filteredBookings = Records.sortNewestFirst(
      allBookings.where((booking) {
        // Searching by Order Number or Port
        final orderNo = (booking.orderNumber ?? "").toString().toLowerCase();
        final pol = (booking.portOfLoadingC ?? "").toString().toLowerCase();
        final pod = (booking.portOfDestinationC ?? "").toString().toLowerCase();

        final matchesSearch =
            orderNo.contains(lastSearchQuery) ||
            pol.contains(lastSearchQuery) ||
            pod.contains(lastSearchQuery);
        final currentStatus =
            (booking.customStatusC ?? booking.trackingStatusC ?? "")
                .toString()
                .toLowerCase();
        final matchesStatus =
            selectedFilter == 'All' ||
            currentStatus == selectedFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList(),
    );

    update();
  }

  Map<String, dynamic>? bookingDetailData;
  List<OrderDocumentModel> orderDocuments = [];
  List<Records> inProgressBookings = [];
  final Map<String, SavedQuotationsModel> inProgressAdminQuoteById = {};
  final Map<String, shipment.Records> inProgressShipmentRecordById = {};

  Future<void> getInProgressBookings({bool accountScoped = false}) async {
    isInProgressLoading.value = true;
    inProgressLoadFailed = false;
    // Clear immediately so a previous user's bookings are never briefly shown.
    filteredBookings.clear();
    inProgressBookings.clear();
    inProgressAdminQuoteById.clear();
    inProgressShipmentRecordById.clear();
    update();

    try {
      final accountId =
          AuthDataHelper.getAccountId().trim().isNotEmpty
              ? AuthDataHelper.getAccountId().trim()
              : (DbHelper().getUserModel()?.accountId?.trim() ?? '');
      debugPrint('📡 getInProgressBookings for account: $accountId');

      final data = await ApiProvider().fetchInProgressShipmentData(
        accountScoped: accountScoped,
      );
      final newest = Records.sortNewestFirst(data.records);
      filteredBookings
        ..clear()
        ..addAll(newest);
      inProgressBookings
        ..clear()
        ..addAll(newest);
      inProgressAdminQuoteById
        ..clear()
        ..addAll(data.adminQuoteById);
      inProgressShipmentRecordById
        ..clear()
        ..addAll(data.shipmentRecordById);
      inProgressLoadFailed = false;
      update();
    } catch (e) {
      inProgressLoadFailed = true;
      debugPrint('IN PROGRESS SHIPMENTS ERROR => $e');
    } finally {
      isInProgressLoading.value = false;
      update();
    }
  }

  List<BookingItem> bookingDetailItems = [];
  Future<void> fetchBookingDetails({
    required String quoteId,
    required String orderId,
  }) async {
    try {
      isLoading.value = true;
      update();

      final accountId = DbHelper().getUserModel()?.accountId ?? "";

      /// =========================
      /// DETAIL API
      /// =========================

      ApiRequest detailRequest = ApiRequest(
        url: ApiConstants.detailedBooking(accountId, quoteId),

        method: DioMethod.get,
      );

      final detailResponse = await BaseClient().handleRequest(detailRequest);

      debugPrint("DETAIL RESPONSE : $detailResponse");

      if (detailResponse != null && detailResponse['status'] == 200) {
        final bookings = detailResponse['bookings'] as List<dynamic>;
        bookingDetailData = bookings.firstWhere(
          (b) => b['Id'] == orderId,
          orElse: () => bookings.isNotEmpty ? bookings[0] : null,
        );

        if (bookingDetailData is Map) {
          await ShipmentStatusNotificationService.processOrderMap(
            Map<String, dynamic>.from(bookingDetailData as Map),
          );
        }
      }

      final documentsResponse = await ApiProvider().fetchOrderDocuments(
        orderId: orderId,
      );

      if (documentsResponse.success == true ||
          documentsResponse.code == 200 ||
          (documentsResponse.body?.isNotEmpty ?? false)) {
        orderDocuments = documentsResponse.body ?? [];
      } else {
        orderDocuments = [];
        ApiProvider.debugLogOrderDocuments(
          orderId: orderId,
          documents: const [],
          source: 'fetchBookingDetails (failed or empty)',
          stats: OrderDocumentsFetchStats(
            orderId: orderId,
            backendFileCount: 0,
            uiFileCount: 0,
            skippedDuplicates: 0,
            skippedQuotePdf: 0,
            skippedNoDisplayData: 0,
            skippedInvalidItem: 0,
            notShownInUi: const [],
          ),
        );
      }
    } catch (e) {
      debugPrint("DETAIL ERROR : $e");
    }

    isLoading.value = false;
    update();
  }
}
