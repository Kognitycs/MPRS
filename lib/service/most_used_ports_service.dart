import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/api_provider.dart';
import 'package:mprs_android/core/constants/base_client.dart';
import 'package:mprs_android/core/constants/port_preference_keys.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/model/get_booking_list_model_new.dart' as booking;
import 'package:mprs_android/model/saved_quotations_model.dart';
import 'package:get/get.dart';

/// Result of resolving most-used port of loading / discharge for Preferences.
class MostUsedPortsResult {
  final String? portOfLoading;
  final String? portOfDischarge;
  final int loadingUseCount;
  final int dischargeUseCount;
  final bool fromCache;

  const MostUsedPortsResult({
    this.portOfLoading,
    this.portOfDischarge,
    this.loadingUseCount = 0,
    this.dischargeUseCount = 0,
    this.fromCache = false,
  });

  bool get hasLoading => (portOfLoading ?? '').trim().isNotEmpty;
  bool get hasDischarge => (portOfDischarge ?? '').trim().isNotEmpty;
}

/// Aggregates port usage from bookings, quotes, and local activity (user + admin).
class MostUsedPortsService {
  static const Duration _cacheTtl = Duration(hours: 6);

  static String _normalizeKey(String? value) =>
      (value ?? '').trim().toLowerCase();

  static void _addUsage(
    Map<String, int> counts,
    Map<String, String> labels,
    String? raw,
  ) {
    final trimmed = (raw ?? '').trim();
    final key = _normalizeKey(trimmed);
    if (key.isEmpty) return;
    counts[key] = (counts[key] ?? 0) + 1;
    labels.putIfAbsent(key, () => trimmed);
  }

  static Map<String, int> _decodeCounts(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, int>> _loadLocalCounts(String prefKey) async {
    try {
      final raw = PreferenceUtils.getString(prefKey, '');
      if (raw.isEmpty) return {};
      return _decodeCounts(raw);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveLocalCounts(
    String prefKey,
    Map<String, int> counts,
  ) async {
    try {
      await PreferenceUtils.setString(prefKey, jsonEncode(counts));
    } catch (e) {
      debugPrint('MostUsedPortsService: save local counts failed: $e');
    }
  }

  /// Records ports the user selected (search, quote, etc.) — never throws.
  static Future<void> recordPortUsage({
    String? portOfLoading,
    String? portOfDischarge,
  }) async {
    try {
      if ((portOfLoading ?? '').trim().isNotEmpty) {
        final pol = await _loadLocalCounts(PortPreferenceKeys.polUsageJson);
        final key = _normalizeKey(portOfLoading);
        pol[key] = (pol[key] ?? 0) + 1;
        await _saveLocalCounts(PortPreferenceKeys.polUsageJson, pol);
      }
      if ((portOfDischarge ?? '').trim().isNotEmpty) {
        final pod = await _loadLocalCounts(PortPreferenceKeys.podUsageJson);
        final key = _normalizeKey(portOfDischarge);
        pod[key] = (pod[key] ?? 0) + 1;
        await _saveLocalCounts(PortPreferenceKeys.podUsageJson, pod);
      }
      await PreferenceUtils.remove(PortPreferenceKeys.cachedAtMs);
    } catch (e) {
      debugPrint('MostUsedPortsService.recordPortUsage: $e');
    }
  }

  MostUsedPortsResult? _readCache() {
    try {
      final atMs = PreferenceUtils.getInt(PortPreferenceKeys.cachedAtMs, 0);
      if (atMs <= 0) return null;
      final age = DateTime.now().millisecondsSinceEpoch - atMs;
      if (age > _cacheTtl.inMilliseconds) return null;

      final pol = PreferenceUtils.getString(PortPreferenceKeys.cachedPol, '');
      final pod = PreferenceUtils.getString(PortPreferenceKeys.cachedPod, '');
      if (pol.isEmpty && pod.isEmpty) return null;

      return MostUsedPortsResult(
        portOfLoading: pol.isEmpty ? null : pol,
        portOfDischarge: pod.isEmpty ? null : pod,
        loadingUseCount:
            PreferenceUtils.getInt(PortPreferenceKeys.cachedPolCount, 0),
        dischargeUseCount:
            PreferenceUtils.getInt(PortPreferenceKeys.cachedPodCount, 0),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(MostUsedPortsResult result) async {
    try {
      await PreferenceUtils.setString(
        PortPreferenceKeys.cachedPol,
        result.portOfLoading ?? '',
      );
      await PreferenceUtils.setString(
        PortPreferenceKeys.cachedPod,
        result.portOfDischarge ?? '',
      );
      await PreferenceUtils.setInt(
        PortPreferenceKeys.cachedPolCount,
        result.loadingUseCount,
      );
      await PreferenceUtils.setInt(
        PortPreferenceKeys.cachedPodCount,
        result.dischargeUseCount,
      );
      await PreferenceUtils.setInt(
        PortPreferenceKeys.cachedAtMs,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('MostUsedPortsService._writeCache: $e');
    }
  }

  static String? _topPort(
    Map<String, int> counts,
    Map<String, String> labels,
  ) {
    if (counts.isEmpty) return null;
    String? bestKey;
    var bestCount = 0;
    counts.forEach((key, count) {
      if (count > bestCount) {
        bestCount = count;
        bestKey = key;
      }
    });
    if (bestKey == null || bestCount <= 0) return null;
    return labels[bestKey] ?? bestKey;
  }

  static void _mergeCounts(
    Map<String, int> target,
    Map<String, int> source,
  ) {
    source.forEach((key, count) {
      if (count > 0) target[key] = (target[key] ?? 0) + count;
    });
  }

  /// Resolves most-used POL/POD; safe — returns empty fields on failure.
  Future<MostUsedPortsResult> resolve({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCache();
      if (cached != null) return cached;
    }

    final polCounts = <String, int>{};
    final podCounts = <String, int>{};
    final polLabels = <String, String>{};
    final podLabels = <String, String>{};

    try {
      _mergeCounts(polCounts, await _loadLocalCounts(PortPreferenceKeys.polUsageJson));
      _mergeCounts(podCounts, await _loadLocalCounts(PortPreferenceKeys.podUsageJson));

      await _aggregateFromRemote(
        polCounts: polCounts,
        podCounts: podCounts,
        polLabels: polLabels,
        podLabels: podLabels,
      );

      final topPol = _topPort(polCounts, polLabels);
      final topPod = _topPort(podCounts, podLabels);
      final polKey = _normalizeKey(topPol);
      final podKey = _normalizeKey(topPod);

      final result = MostUsedPortsResult(
        portOfLoading: topPol,
        portOfDischarge: topPod,
        loadingUseCount: polKey.isEmpty ? 0 : (polCounts[polKey] ?? 0),
        dischargeUseCount: podKey.isEmpty ? 0 : (podCounts[podKey] ?? 0),
      );

      await _writeCache(result);
      return result;
    } catch (e, st) {
      debugPrint('MostUsedPortsService.resolve failed: $e\n$st');
      return const MostUsedPortsResult();
    }
  }

  Future<void> _aggregateFromRemote({
    required Map<String, int> polCounts,
    required Map<String, int> podCounts,
    required Map<String, String> polLabels,
    required Map<String, String> podLabels,
  }) async {
    void addPair({String? pol, String? pod}) {
      _addUsage(polCounts, polLabels, pol);
      _addUsage(podCounts, podLabels, pod);
    }

    if (AuthDataHelper.isAdminUser()) {
      try {
        final quotes = await ApiProvider().fetchAdminAppCreatedQuotations();
        for (final q in quotes) {
          addPair(
            pol: q.originPortR?.name,
            pod: q.destinationPortR?.name,
          );
        }
      } catch (e) {
        debugPrint('MostUsedPortsService admin quotes: $e');
      }

      try {
        final orders = await ApiProvider().fetchAdminRmsBookedOrders();
        for (final o in orders) {
          addPair(
            pol: o.portOfLoadingC?.toString(),
            pod: o.portOfDestinationC?.toString(),
          );
        }
      } catch (e) {
        debugPrint('MostUsedPortsService admin orders: $e');
      }
      return;
    }

    try {
      final bookingCtrl = Get.isRegistered<BookingController>(tag: 'all_bookings')
          ? Get.find<BookingController>(tag: 'all_bookings')
          : Get.put(BookingController(), tag: 'all_bookings');
      await bookingCtrl.getConfirmedBookings();
      await bookingCtrl.getInProgressBookings();

      for (final b in bookingCtrl.allBookings) {
        addPair(
          pol: b.portOfLoadingC?.toString(),
          pod: b.portOfDestinationC?.toString(),
        );
      }
      for (final b in bookingCtrl.inProgressBookings) {
        addPair(
          pol: b.portOfLoadingC?.toString(),
          pod: b.portOfDestinationC?.toString(),
        );
      }
    } catch (e) {
      debugPrint('MostUsedPortsService user bookings: $e');
    }

    for (final o in await _loadSfBookedOrders()) {
      addPair(
        pol: o.portOfLoadingC?.toString(),
        pod: o.portOfDestinationC?.toString(),
      );
    }

    for (final q in await _loadUserQuotes()) {
      addPair(
        pol: q.originPortR?.name,
        pod: q.destinationPortR?.name,
      );
    }
  }

  Future<List<booking.Records>> _loadSfBookedOrders() async {
    final accountId = AuthDataHelper.getAccountId();
    if (accountId.isEmpty) return [];

    try {
      final response = await BaseClient().handleRequest(
        ApiRequest(
          url: ApiConstants.getDataBookings(accountId),
          method: DioMethod.get,
        ),
      );
      final records = <booking.Records>[];
      final raw = response?['records'];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            records.add(
              booking.Records.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<List<SavedQuotationsModel>> _loadUserQuotes() async {
    final accountId = AuthDataHelper.getAccountId();
    if (accountId.isEmpty) return [];

    final quotes = <SavedQuotationsModel>[];
    for (final url in [
      ApiConstants.getBookingRequestReceived(accountId),
    ]) {
      try {
        final response = await BaseClient().handleRequest(
          ApiRequest(url: url, method: DioMethod.get),
        );
        final raw = response?['records'];
        if (raw is! List) continue;
        for (final item in raw) {
          if (item is Map) {
            quotes.add(
              SavedQuotationsModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      } catch (_) {}
    }
    return quotes;
  }
}
