import 'package:package_info_plus/package_info_plus.dart';

/// Build identity for test vs production APKs.
///
/// - Test APK  → staging API ([_stagingDomain]) + optional `app_name` header
/// - Prod APK  → production API ([_productionDomain]) + optional `app_name` header
///
/// The backend can route by **host** alone; [apiHeaders] is kept for backends
/// that also read `app_name` for Salesforce / logging.
class AppConfig {
  AppConfig._();

  static const apiAppNameHeaderKey = 'app_name';

  static const _productionDomain = 'https://genie.mprsshipping.com';
  static const _stagingDomain = 'https://tech.mprsshipping.com';

  static const _productionHeader = 'mprs genie';
  static const _testHeader = 'mprs genie test';

  /// iOS bundle IDs (Android uses Gradle flavors + applicationIdSuffix).
  static const iosProductionBundleId = 'com.mprsshipping.genie';
  static const iosStagingBundleId = 'com.mprsshipping.genie.test';

  static String _packageName = 'com.mobile.mprs_android';
  static bool _initialized = false;

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _packageName = info.packageName;
    _initialized = true;
  }

  static bool get isTestBuild =>
      _packageName == 'com.mobile.mprs_android.test' ||
      _packageName.endsWith('.test');

  static String get domain => isTestBuild ? _stagingDomain : _productionDomain;

  /// API root, e.g. `https://tech.mprsshipping.com/api` (test).
  static String get baseUrl => '$domain/api';

  static String get apiAppNameHeader =>
      isTestBuild ? _testHeader : _productionHeader;

  static String get displayName =>
      isTestBuild ? 'MPRS Genie Test' : 'MPRS Genie';

  static Map<String, String> get apiHeaders => {
    apiAppNameHeaderKey: apiAppNameHeader,
  };

  static Map<String, String> mergeApiHeaders(Map<String, String>? headers) {
    return {...apiHeaders, ...?headers};
  }

  static bool get isInitialized => _initialized;
}
