import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/controller/saved_quotations_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/service/sales_account_directory.dart';

/// Home stats for internal (sales) users — live APIs only (no mock figures).
class InternalHomeStats {
  final int accountCount;
  final List<SalesAccountChoice> accounts;
  final int orderCount;
  final int openQuoteCount;
  final int acceptedQuoteCount;
  final SalesAccountCustomerTierCounts customerTiers;
  final List<SavedQuotationsModel> portfolioQuotes;

  const InternalHomeStats({
    required this.accountCount,
    required this.accounts,
    required this.orderCount,
    required this.openQuoteCount,
    required this.acceptedQuoteCount,
    required this.customerTiers,
    required this.portfolioQuotes,
  });

  static const empty = InternalHomeStats(
    accountCount: 0,
    accounts: [],
    orderCount: 0,
    openQuoteCount: 0,
    acceptedQuoteCount: 0,
    customerTiers: SalesAccountCustomerTierCounts.zero,
    portfolioQuotes: [],
  );
}

class InternalHomeStatsService {
  /// Minimum rows shown on internal Analytics → Top Search Routes.
  static const int internalTopSearchRoutesMinDisplay = 5;
  static const int internalTopSearchRoutesMaxDisplay = 10;

  static Future<InternalHomeStats> load({bool refreshBookings = false}) async {
    if (!Get.isRegistered<SavedQuotationsController>()) {
      Get.put(SavedQuotationsController());
    }

    final accountLoadFuture = SalesAccountDirectory.loadForCurrentUser();

    if (refreshBookings &&
        Get.isRegistered<BookingController>(
          tag: BookingController.homeBookingsTag,
        )) {
      final booking =
          Get.find<BookingController>(tag: BookingController.homeBookingsTag);
      final quotes = Get.find<SavedQuotationsController>();
      await Future.wait([
        accountLoadFuture,
        booking.getConfirmedBookings(),
        quotes.fetchSavedQuotes(),
        booking.getInProgressBookings(),
      ]);
    }

    final accountLoad = await accountLoadFuture;
    final accounts = accountLoad.choices;
    final customerTiers = SalesAccountCustomerTierCounts.fromAccounts(accounts);

    var orderCount = 0;
    if (Get.isRegistered<BookingController>(tag: BookingController.homeBookingsTag)) {
      orderCount = BookingController.bookedOrderRows(
        Get.find<BookingController>(tag: BookingController.homeBookingsTag)
            .allBookings,
      ).length;
    }

    final mergedQuotes = _portfolioQuotesForStats();
    final openQuoteCount =
        mergedQuotes
            .where((q) => SavedQuotationsModel.isDraftStatus(q.status))
            .length;
    final acceptedQuoteCount =
        mergedQuotes
            .where((q) => SavedQuotationsModel.isAcceptedStatus(q.status))
            .length;

    return InternalHomeStats(
      accountCount: accounts.length,
      accounts: accounts,
      orderCount: orderCount,
      openQuoteCount: openQuoteCount,
      acceptedQuoteCount: acceptedQuoteCount,
      customerTiers: customerTiers,
      portfolioQuotes: mergedQuotes,
    );
  }

  /// Top origin → destination pairs from portfolio quotes (for analytics).
  static List<Map<String, dynamic>> topSearchRoutesFromQuotes(
    List<SavedQuotationsModel> quotes, {
    String? originFilter,
    String? destinationFilter,
    int limit = 7,
  }) {
    final originQ = originFilter?.trim().toLowerCase() ?? '';
    final destQ = destinationFilter?.trim().toLowerCase() ?? '';
    final grouped = <String, int>{};

    for (final quote in quotes) {
      if (!quote.hasResolvedPorts) continue;
      final pol = quote.originPortR?.name?.trim() ?? '';
      final pod = quote.destinationPortR?.name?.trim() ?? '';
      if (pol.isEmpty && pod.isEmpty) continue;
      if (originQ.isNotEmpty && !pol.toLowerCase().contains(originQ)) continue;
      if (destQ.isNotEmpty && !pod.toLowerCase().contains(destQ)) continue;
      final label =
          pol.isNotEmpty && pod.isNotEmpty
              ? '$pol → $pod'
              : (pol.isNotEmpty ? pol : pod);
      grouped[label] = (grouped[label] ?? 0) + 1;
    }

    final rows =
        grouped.entries
            .map((e) => {'label': e.key, 'count': e.value})
            .toList();
    rows.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (rows.length > limit) return rows.sublist(0, limit);
    return rows;
  }

  /// RMS app searches (opportunities) + portfolio quotes, for internal analytics.
  static Future<List<Map<String, dynamic>>> loadTopSearchRoutesForInternal({
    required List<SavedQuotationsModel> portfolioQuotes,
  }) async {
    final counts = <String, int>{};

    for (final row in topSearchRoutesFromQuotes(portfolioQuotes, limit: 999)) {
      final label = row['label']?.toString().trim() ?? '';
      if (label.isEmpty) continue;
      counts[label] = (counts[label] ?? 0) + (row['count'] as int? ?? 0);
    }

    await _mergePortfolioOpportunitySearchRoutes(counts);

    final rows =
        counts.entries
            .map((e) => {'label': e.key, 'count': e.value})
            .toList();
    rows.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final displayCount = _internalTopSearchRouteDisplayCount(rows.length);
    if (displayCount <= 0) return const [];
    return rows.sublist(0, displayCount);
  }

  static int _internalTopSearchRouteDisplayCount(int available) {
    if (available <= 0) return 0;
    if (available < internalTopSearchRoutesMinDisplay) return available;
    if (available > internalTopSearchRoutesMaxDisplay) {
      return internalTopSearchRoutesMaxDisplay;
    }
    return available;
  }

  static Future<void> _mergePortfolioOpportunitySearchRoutes(
    Map<String, int> counts,
  ) async {
    try {
      final portfolioIds = await SalesAccountDirectory.portfolioAccountIdSet();
      if (portfolioIds.isEmpty) return;

      final token = AuthDataHelper.getToken();
      if (token.trim().isEmpty) return;

      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.rmsAppOpportunities(),
        token,
      );
      if (response.statusCode != 200) return;

      final body = response.data;
      final decoded = body is String ? jsonDecode(body) : body;
      for (final row in _opportunityRecordMaps(decoded)) {
        final accountId = row['AccountId']?.toString().trim() ?? '';
        if (accountId.isEmpty || !portfolioIds.contains(accountId)) continue;

        final origin = _portNameFromSfRelation(row['Origin_Port__r']);
        final destination = _portNameFromSfRelation(row['Destination_Port__r']);
        if (origin.isEmpty || destination.isEmpty) continue;

        final label = '$origin → $destination';
        counts[label] = (counts[label] ?? 0) + 1;
      }
    } catch (e, st) {
      debugPrint('InternalHomeStatsService top search routes: $e\n$st');
    }
  }

  static List<Map<String, dynamic>> _opportunityRecordMaps(dynamic decoded) {
    List<dynamic> raw = const [];
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map) {
      for (final key in ['records', 'data', 'body', 'result']) {
        final value = decoded[key];
        if (value is List) {
          raw = value;
          break;
        }
        if (value is Map) {
          final nested = value['records'] ?? value['data'];
          if (nested is List) {
            raw = nested;
            break;
          }
        }
      }
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String _portNameFromSfRelation(dynamic port) {
    if (port is Map) return port['Name']?.toString().trim() ?? '';
    return '';
  }

  /// Recent quotations + in-progress map (portfolio), deduped by quote id.
  static List<SavedQuotationsModel> _portfolioQuotesForStats() {
    final byId = <String, SavedQuotationsModel>{};
    if (Get.isRegistered<SavedQuotationsController>()) {
      for (final quote in Get.find<SavedQuotationsController>().quotesList) {
        final id = quote.id?.trim() ?? '';
        if (id.isEmpty) continue;
        byId[id] = SavedQuotationsModel.merge([byId[id], quote]) ?? quote;
      }
    }
    if (Get.isRegistered<BookingController>(tag: BookingController.homeBookingsTag)) {
      for (final quote
          in Get.find<BookingController>(tag: BookingController.homeBookingsTag)
              .inProgressAdminQuoteById
              .values) {
        final id = quote.id?.trim() ?? '';
        if (id.isEmpty || quote.isTestQuoteData) continue;
        byId[id] = SavedQuotationsModel.merge([byId[id], quote]) ?? quote;
      }
    }
    return byId.values.toList();
  }
}