import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mprs_android/service/admin_booking_counts_service.dart';

/// Single source of truth for admin booking pie counts (dashboard + analytics).
class AdminBookingCountsController extends GetxController {
  final RxMap<String, int> bookingCounts = RxMap<String, int>({
    'Cancelled': 0,
    'Delivered': 0,
    'Scheduled': 0,
    'Shipped': 0,
  });

  final RxBool isLoading = false.obs;

  Future<void>? _loadFuture;

  int get total => AdminBookingCountsService.totalOf(
        Map<String, int>.from(bookingCounts),
      );

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Loads counts once; concurrent callers share the same in-flight request.
  Future<void> load({bool forceRefresh = false}) async {
    if (_loadFuture != null && !forceRefresh) {
      await _loadFuture;
      return;
    }

    isLoading.value = true;
    _loadFuture = _fetch(forceRefresh: forceRefresh);
    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
      isLoading.value = false;
    }
  }

  Future<void> _fetch({required bool forceRefresh}) async {
    try {
      final counts = await AdminBookingCountsService.fetchAll(
        forceRefresh: forceRefresh,
      );
      bookingCounts.assignAll(counts);
      debugPrint(
        '📊 AdminBookingCountsController updated: $counts (total=$total)',
      );
    } catch (e, st) {
      debugPrint('❌ AdminBookingCountsController: $e');
      debugPrint('$st');
    }
  }

  static AdminBookingCountsController ensureRegistered() {
    if (Get.isRegistered<AdminBookingCountsController>()) {
      return Get.find<AdminBookingCountsController>();
    }
    return Get.put(AdminBookingCountsController(), permanent: true);
  }
}
