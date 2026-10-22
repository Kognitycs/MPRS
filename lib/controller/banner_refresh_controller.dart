import 'package:get/get.dart';
import 'package:mprs_android/model/banner_item.dart';

/// Notifies banner carousels and banner management to reload after changes.
class BannerRefreshController extends GetxController {
  final refreshTick = 0.obs;
  BannerItem? lastUpdatedBanner;

  static BannerRefreshController ensureRegistered() {
    if (Get.isRegistered<BannerRefreshController>()) {
      return Get.find<BannerRefreshController>();
    }
    return Get.put(BannerRefreshController(), permanent: true);
  }

  void notifyChanged({BannerItem? updatedBanner}) {
    if (updatedBanner != null) {
      lastUpdatedBanner = updatedBanner;
    }
    refreshTick.value++;
  }
}
