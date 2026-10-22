import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart' as booking;
import 'package:mprs_android/service/http_client_helper.dart';

/// Analytics report booking period (always clamped to the current calendar year).
enum BookingAnalyticsPeriod {
  thisWeek('This week'),
  thisMonth('This month'),
  threeMonths('3 months'),
  sixMonths('6 months'),
  thisYear('This year');

  const BookingAnalyticsPeriod(this.label);
  final String label;

  DateTime get startDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yearStart = DateTime(now.year, 1, 1);

    late DateTime from;
    switch (this) {
      case BookingAnalyticsPeriod.thisWeek:
        from = today.subtract(Duration(days: today.weekday - 1));
        break;
      case BookingAnalyticsPeriod.thisMonth:
        from = DateTime(now.year, now.month, 1);
        break;
      case BookingAnalyticsPeriod.threeMonths:
        from = DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 90),
        );
        break;
      case BookingAnalyticsPeriod.sixMonths:
        from = DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 182),
        );
        break;
      case BookingAnalyticsPeriod.thisYear:
        from = yearStart;
        break;
    }

    return from.isBefore(yearStart) ? yearStart : from;
  }
}

/// Total Reach filter options for analytics report.
enum ReachAnalyticsPeriod {
  allTime('All time'),
  thisWeek('This week'),
  thisMonth('This month'),
  thisYear('This year');

  const ReachAnalyticsPeriod(this.label);
  final String label;

  static ReachAnalyticsPeriod fromLabel(String label) {
    return ReachAnalyticsPeriod.values.firstWhere(
      (p) => p.label == label,
      orElse: () => ReachAnalyticsPeriod.allTime,
    );
  }

  DateTime? get fromDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case ReachAnalyticsPeriod.allTime:
        return null;
      case ReachAnalyticsPeriod.thisWeek:
        return today.subtract(Duration(days: today.weekday - 1));
      case ReachAnalyticsPeriod.thisMonth:
        return DateTime(now.year, now.month, 1);
      case ReachAnalyticsPeriod.thisYear:
        return DateTime(now.year, 1, 1);
    }
  }

  DateTime? get toDate {
    if (this == ReachAnalyticsPeriod.allTime) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// Booking counts for the admin dashboard — only RMS-app orders are counted.
class AdminBookingCountsService {
  AdminBookingCountsService._();

  static const List<String> statuses = [
    'Cancelled',
    'Delivered',
    'Scheduled',
    'Shipped',
  ];

  /// Legend / pie draw order (matches dashboard colors).
  static const List<String> chartOrder = [
    'Delivered',
    'Shipped',
    'Scheduled',
    'Cancelled',
  ];

  static Map<String, int>? _cache;
  static Future<Map<String, int>>? _inFlight;
  static List<booking.Records>? _cachedOrders;
  static Future<List<booking.Records>>? _ordersInFlight;

  static Map<String, int> emptyCounts() => {
        for (final s in statuses) s: 0,
      };

  static Map<String, int> orderedCounts(Map<String, int> raw) {
    final ordered = <String, int>{};
    for (final status in chartOrder) {
      ordered[status] = raw[status] ?? 0;
    }
    for (final status in statuses) {
      ordered.putIfAbsent(status, () => raw[status] ?? 0);
    }
    return ordered;
  }

  /// Pie slices from API counts — only segments with value > 0 (true proportions).
  static List<MapEntry<String, double>> pieSliceValues(Map<String, int> raw) {
    final counts = orderedCounts(raw);
    final slices = <MapEntry<String, double>>[];
    for (final status in chartOrder) {
      final value = counts[status] ?? 0;
      if (value > 0) {
        slices.add(MapEntry(status, value.toDouble()));
      }
    }
    return slices;
  }

  static Map<String, dynamic> _unwrapMap(Map<String, dynamic> map) {
    final data = map['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    final result = map['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return map;
  }

  /// Prefer [records].length — API `count` can disagree with returned rows.
  static int parseCount(dynamic decoded, {String? statusLabel}) {
    if (decoded is Map) {
      final map = _unwrapMap(Map<String, dynamic>.from(decoded));
      final records = map['records'] ?? map['bookings'] ?? map['items'];
      if (records is List) {
        final fromRecords = records.length;
        final countField = map['count'] ??
            map['total'] ??
            map['totalCount'] ??
            map['bookingCount'];
        if (countField is num && countField.round() != fromRecords) {
          debugPrint(
            '⚠️ [$statusLabel] API count=${countField.round()} '
            '≠ records.length=$fromRecords — using records',
          );
        }
        return fromRecords;
      }
      final countField = map['count'] ??
          map['total'] ??
          map['totalCount'] ??
          map['bookingCount'];
      if (countField is num) return countField.round();
    }
    if (decoded is List) return decoded.length;
    if (statusLabel != null) {
      debugPrint('⚠️ [$statusLabel] unexpected booking response shape');
    }
    return 0;
  }

  static String? _normalizeStatusLabel(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    for (final s in statuses) {
      if (text.toLowerCase() == s.toLowerCase()) return s;
    }
    final lower = text.toLowerCase();

    // Cancelled
    if (lower.contains('cancel')) return 'Cancelled';

    // Delivered — includes post-clearance states
    if (lower.contains('deliver')) return 'Delivered';
    if (lower.contains('discharg')) return 'Delivered';
    if (lower.contains('clear')) return 'Delivered';
    if (lower.contains('return')) return 'Delivered';

    // Shipped — vessel/transit states
    if (lower.contains('ship')) return 'Shipped';
    if (lower.contains('on board')) return 'Shipped';
    if (lower.contains('onboard')) return 'Shipped';
    if (lower.contains('vessel sail')) return 'Shipped';
    if (lower.contains('sailed')) return 'Shipped';
    if (lower.contains('transship')) return 'Shipped';
    if (lower.contains('in transit')) return 'Shipped';
    if (lower.contains('arrival')) return 'Shipped';

    // Scheduled — pre-departure states
    if (lower.contains('schedul')) return 'Scheduled';
    if (lower.contains('gated')) return 'Scheduled';
    if (lower.contains('picked up')) return 'Scheduled';
    if (lower.contains('booking')) return 'Scheduled';
    if (lower.contains('booked')) return 'Scheduled';
    if (lower.contains('received')) return 'Scheduled';
    if (lower.contains('sent')) return 'Scheduled';

    return null;
  }

  static int totalOf(Map<String, int> counts) =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  /// Same logic as the original admin dashboard: `records.length` per status.
  static int _countFromStatusResponse(dynamic decoded) {
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final records = map['records'];
      if (records is List) return records.length;

      final count = map['count'] ?? map['total'] ?? map['totalCount'];
      if (count is num) return count.round();
    }
    return parseCount(decoded);
  }

  static Future<MapEntry<String, int>> _fetchForStatus(String status) async {
    final url = ApiConstants.totalBookingsForStatus(status);

    try {
      final response = await HttpClientHelper.getWithBearer(
        url,
        AuthDataHelper.getToken(),
      );

      if (response.statusCode != 200) {
        return MapEntry(status, 0);
      }

      final decoded = jsonDecode(response.data);
      final count = _countFromStatusResponse(decoded);
      return MapEntry(status, count);
    } catch (e) {
      debugPrint('❌ [$status] booking error: $e');
      return MapEntry(status, 0);
    }
  }

  /// Fetches all RMS-app orders via ApiProvider (proven BaseClient auth) and
  /// buckets them by status to produce per-bucket counts.
  static DateTime? _orderDate(booking.Records order) {
    for (final raw in [
      order.bookedDateC,
      order.createdDate,
      order.vesselSailedDateC,
      order.onBoardDateC,
      order.pickedUpDateC,
    ]) {
      if (raw == null || raw.toString().trim().isEmpty) continue;
      final text = raw.toString().trim();
      final parsed = DateTime.tryParse(text.split('T').first) ??
          DateTime.tryParse(text);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static Map<String, int> _countsFromOrders(
    List<booking.Records> orders, {
    DateTime? from,
    DateTime? to,
  }) {
    final counts = emptyCounts();
    final end = to ?? DateTime.now();

    for (final order in orders) {
      final date = _orderDate(order);
      if (from != null) {
        if (date == null) continue;
        if (date.isBefore(from)) continue;
      }
      if (date != null && date.isAfter(end)) continue;

      final raw = (order.trackingStatusC ?? order.customStatusC ?? '').toString();
      final normalized = _normalizeStatusLabel(raw);
      if (normalized != null) {
        counts[normalized] = (counts[normalized] ?? 0) + 1;
      } else {
        counts['Scheduled'] = (counts['Scheduled'] ?? 0) + 1;
      }
    }

    return orderedCounts(counts);
  }

  static Future<List<booking.Records>> _fetchOrdersOnce({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedOrders != null) {
      return _cachedOrders!;
    }
    if (_ordersInFlight != null && !forceRefresh) {
      return _ordersInFlight!;
    }

    final future = ApiProvider().fetchAdminRmsBookedOrders().then((orders) {
      _cachedOrders = orders;
      return orders;
    });

    _ordersInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_ordersInFlight, future)) {
        _ordersInFlight = null;
      }
    }
  }

  /// Bookings pie for analytics — filtered to [period] within the current year.
  static Future<Map<String, int>> fetchForPeriod(
    BookingAnalyticsPeriod period, {
    bool forceRefresh = false,
  }) async {
    final orders = await _fetchOrdersOnce(forceRefresh: forceRefresh);
    final from = period.startDate;
    final counts = _countsFromOrders(orders, from: from);
    debugPrint(
      '📊 Analytics bookings [${period.label}] from ${from.toIso8601String().split('T').first}: '
      '$counts (total=${totalOf(counts)})',
    );
    return counts;
  }

  static Future<Map<String, int>> _fetchRmsOnlyViaProvider() async {
    debugPrint('📡 RMS booking counts: fetching via ApiProvider…');
    try {
      final orders = await _fetchOrdersOnce(forceRefresh: true);
      debugPrint('📦 RMS orders fetched: ${orders.length} record(s)');

      final counts = _countsFromOrders(orders);
      debugPrint('📊 RMS booking counts: $counts  (total=${totalOf(counts)})');
      return counts;
    } catch (e) {
      debugPrint('⚠️ RMS bookings via ApiProvider error: $e — falling back');
      return _fetchAllFromSeparateStatuses();
    }
  }

  static Future<Map<String, int>> _fetchAllFromSeparateStatuses() async {
    final results = await Future.wait(statuses.map(_fetchForStatus));
    return orderedCounts(Map<String, int>.fromEntries(results));
  }

  static Future<Map<String, int>> _fetchAllFromNetwork() async {
    debugPrint('🔄 AdminBookingCountsService — RMS-app-only fetch');
    final counts = await _fetchRmsOnlyViaProvider();
    return orderedCounts(counts);
  }

  /// Fetches all four status buckets. Reuses cache / in-flight unless [forceRefresh].
  static Future<Map<String, int>> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      debugPrint('📊 AdminBookingCountsService — cache hit: $_cache');
      return Map<String, int>.from(_cache!);
    }

    if (_inFlight != null && !forceRefresh) {
      return _inFlight!;
    }

    final future = _fetchAllFromNetwork().then((counts) {
      _cache = Map<String, int>.from(counts);
      return counts;
    });

    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static void clearCache() {
    _cache = null;
    _inFlight = null;
    _cachedOrders = null;
    _ordersInFlight = null;
  }
}
