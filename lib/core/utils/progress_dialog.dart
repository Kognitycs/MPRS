import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';


class ProgressLoader {
  static bool _isShowing = false;

  static void show(BuildContext context) {
    if (_isShowing) return;
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppColors.main,),
      ),
    );
  }

  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
