import 'package:mprs_android/controller/banner_refresh_controller.dart';
import 'package:mprs_android/core/utils/banner_local_image_store.dart';
import 'package:mprs_android/model/banner_item.dart';

class BannerListUtil {
  static List<BannerItem> applyLatestUpdate(List<BannerItem> banners) {
    final latest = BannerRefreshController.ensureRegistered().lastUpdatedBanner;
    if (latest == null) return banners;

    final updated = List<BannerItem>.from(banners);
    final index = updated.indexWhere((b) => b.bannerId == latest.bannerId);
    if (index >= 0) {
      updated[index] = latest;
    } else if (latest.isActive) {
      updated.insert(0, latest);
    }
    return updated;
  }

  static List<BannerItem> finalizeFetchedBanners(List<BannerItem> banners) {
    for (final banner in banners) {
      BannerLocalImageStore.clearIfServerUpdated(
        banner.bannerId,
        banner.updatedAt,
      );
    }
    return applyLatestUpdate(banners);
  }
}
