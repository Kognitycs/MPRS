/// Keeps a local image path per banner so UI can show the newly picked
/// image immediately after update, even before the list API returns a new URL.
class BannerLocalImageStore {
  static final Map<String, String> _paths = {};
  static final Map<String, DateTime> _savedAt = {};

  static void set(String bannerId, String filePath) {
    if (bannerId.isEmpty || filePath.isEmpty) return;
    _paths[bannerId] = filePath;
    _savedAt[bannerId] = DateTime.now();
  }

  static String? get(String bannerId) {
    if (bannerId.isEmpty) return null;
    return _paths[bannerId];
  }

  static void clearIfServerUpdated(String bannerId, DateTime serverUpdatedAt) {
    final savedAt = _savedAt[bannerId];
    if (savedAt == null) return;

    if (serverUpdatedAt.isAfter(savedAt.add(const Duration(seconds: 1)))) {
      clear(bannerId);
    }
  }

  static void clear(String bannerId) {
    _paths.remove(bannerId);
    _savedAt.remove(bannerId);
  }
}
