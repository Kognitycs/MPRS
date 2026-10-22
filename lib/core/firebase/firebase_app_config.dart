import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/app_secrets.dart';

/// Firebase options for the mprs-rms project — one app per platform flavor.
/// Android values from [android/app/google-services.json].
/// iOS values from [ios/Runner/Firebase/*/GoogleService-Info.plist].
class FirebaseAppConfig {
  FirebaseAppConfig._();

  static const FirebaseOptions _productionAndroid = FirebaseOptions(
    apiKey: AppSecrets.firebaseAndroidApiKey,
    appId: '1:204747542797:android:e8548d434895696cdb2044',
    messagingSenderId: '204747542797',
    projectId: 'mprs-rms',
    storageBucket: 'mprs-rms.firebasestorage.app',
  );

  static const FirebaseOptions _testAndroid = FirebaseOptions(
    apiKey: AppSecrets.firebaseAndroidApiKey,
    appId: '1:204747542797:android:ea57de6b33e14b05db2044',
    messagingSenderId: '204747542797',
    projectId: 'mprs-rms',
    storageBucket: 'mprs-rms.firebasestorage.app',
  );

  static const FirebaseOptions _productionIos = FirebaseOptions(
    apiKey: AppSecrets.firebaseIosApiKey,
    appId: '1:204747542797:ios:75f375bc9569d061db2044',
    messagingSenderId: '204747542797',
    projectId: 'mprs-rms',
    storageBucket: 'mprs-rms.firebasestorage.app',
    iosBundleId: 'com.mprsshipping.genie',
  );

  static const FirebaseOptions _testIos = FirebaseOptions(
    apiKey: AppSecrets.firebaseIosApiKey,
    appId: '1:204747542797:ios:2aa1660f2583cf52db2044',
    messagingSenderId: '204747542797',
    projectId: 'mprs-rms',
    storageBucket: 'mprs-rms.firebasestorage.app',
    iosBundleId: 'com.mprsshipping.genie.test',
  );

  static FirebaseOptions get currentOptions {
    final test = AppConfig.isTestBuild;
    if (!kIsWeb && Platform.isIOS) {
      return test ? _testIos : _productionIos;
    }
    return test ? _testAndroid : _productionAndroid;
  }

  /// Idempotent init — safe from main isolate and background FCM handler.
  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    if (Firebase.apps.isNotEmpty) return;
    if (!AppConfig.isInitialized) {
      await AppConfig.init();
    }
    final flavor = AppConfig.isTestBuild ? 'staging' : 'production';
    debugPrint(
      '🔥 Firebase init: $flavor appId=${currentOptions.appId}',
    );
    await Firebase.initializeApp(options: currentOptions);
  }
}
