class BannerImageUtil {
  static String cacheBustedUrl(
    String url, {
    DateTime? updatedAt,
    int? cacheKey,
  }) {
    if (url.isEmpty) return '';

    final version =
        cacheKey ??
        updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    return '$url${url.contains('?') ? '&' : '?'}v=$version';
  }
}
