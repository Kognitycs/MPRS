import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mprs_android/screens/main_screen.dart';

class NavigationUtil {

  /// Open MainScreen and remove all previous screens (clear stack)
  static void toMainScreen(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false, // removes all previous routes
    );
  }

  /// Go Back or Exit App if no back stack
  static void goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      exitApp();
    }
  }

  /// Exit Application
  static void exitApp() {
    SystemNavigator.pop();
  }
}
