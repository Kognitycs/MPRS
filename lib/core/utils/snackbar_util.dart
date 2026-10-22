import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

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
