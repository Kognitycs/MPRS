import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import 'api_error_utils.dart';

const _serviceErrorSnackCooldown = Duration(seconds: 8);
DateTime? _lastServiceErrorSnackShownAt;

bool _canShowServiceErrorSnack() {
  final now = DateTime.now();
  final last = _lastServiceErrorSnackShownAt;
  if (last != null && now.difference(last) < _serviceErrorSnackCooldown) {
    return false;
  }
  _lastServiceErrorSnackShownAt = now;
  return true;
}

/// API / service failure — never pass raw server or exception text here.
void showServiceErrorSnackBar(
  BuildContext context, {
  Color backgroundColor = Colors.red,
}) {
  if (!_canShowServiceErrorSnack()) return;
  showSnackBar(context, userFacingErrorMessage(), backgroundColor: backgroundColor);
}

void showServiceErrorGetSnackbar({
  String title = 'Error',
  Color backgroundColor = Colors.red,
}) {
  if (!_canShowServiceErrorSnack()) return;
  Get.closeAllSnackbars();
  Get.snackbar(
    title,
    userFacingErrorMessage(),
    backgroundColor: backgroundColor,
    colorText: AppColors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
  );
}

void showSnackBar(BuildContext context, String message, {Color backgroundColor = Colors.black87}) {

  final snackBar = SnackBar(
    content: Text(
      message,
      style: TextStyle(color: AppColors.white),
    ),
    backgroundColor: backgroundColor,
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    // Removed custom margin to avoid 'presented off screen' error
  );

  ScaffoldMessenger.of(context).clearSnackBars(); // Optional: remove previous
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}