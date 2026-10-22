import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mprs_android/core/app_config.dart';
import 'package:mprs_android/core/firebase/firebase_app_config.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_strings.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/core/utils/loader.dart';
import 'package:mprs_android/core/utils/shared_preferences.dart';
import 'package:mprs_android/screens/splash/splash_screen.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/service/fcm_token_service.dart';
import 'package:mprs_android/service/notification/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:webview_flutter_web/webview_flutter_web.dart'; // Isko add karein
import 'package:webview_flutter/webview_flutter.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();

  // requestNotificationPermission();
  // await Firebase.initializeApp();
  await PreferenceUtils.init();
  await DbHelper.init();
  if (!kIsWeb) {
    await AppConfig.init();
    debugPrint(
      '📱 App build: ${AppConfig.displayName} '
      '(header=${AppConfig.apiAppNameHeader}, api=${AppConfig.baseUrl})',
    );
    try {
      await FirebaseAppConfig.ensureInitialized();
      // Must be registered BEFORE runApp so the background isolate finds the handler.
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      FcmTokenService.registerTokenRefreshListener();
      debugPrint('✅ Firebase initialized');
    } catch (e, st) {
      debugPrint('Firebase initialization failed: $e\n$st');
    }
  }

  runApp(const MyApp());
  // Request POST_NOTIFICATIONS on Android 13+ after the widget tree is ready.
  requestNotificationPermission();
}

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage remoteMessage,
) async {
  await firebaseMessagingBackgroundHandler(remoteMessage);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // final NotificationServices _notificationServices = NotificationServices();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // if (!_isInitialized) {
    //   WidgetsBinding.instance.addObserver(this);
    //   _notificationServices.setupNotification(context);
    //   _isInitialized = true;
    // }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("getToken ==============${AuthDataHelper.getToken()}");
    debugPrint("getToken ======DbHelper---3333-----========${DbHelper().getUserToken()}");

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return GetMaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.isInitialized ? AppConfig.displayName : AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "Aptos",
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        cardColor: AppColors.white,
        cardTheme: const CardThemeData(
          color: AppColors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.cardBorder),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: Color(0xFF1C2434),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context),
          child: Stack(
            children: [
              child ?? const SizedBox(),
              Loader.overlay(), // ✅ always on top
            ],
          ),
        );
      },
      routes: {'/login': (context) => const LoginMobileScreen()},
      home: SplashScreen(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Future<void> requestNotificationPermission() async {
  bool? isHigherVersionAndroidDevice = await isAndroidHigherVersion();

  if (isHigherVersionAndroidDevice == true) {
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
}

Future<bool?> isAndroidHigherVersion() async {
  if (Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }
  return false;
}
