import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

/// Shared brand styling for admin and user notification tabs.
class NotificationTheme {
  NotificationTheme._();

  static const Color orange = AppColors.main;

  /// Shipment status alerts — title, header, and body lines.
  static const Color shipmentStatusBlue = AppColors.main;

  static BoxDecoration cardDecoration({Color? background}) {
    return BoxDecoration(
      color: background ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    );
  }

  static const TextStyle titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.main,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: AppColors.main,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: AppColors.main,
  );

  /// Status step label above "Your Shipment …" (shipment alerts only).
  static const TextStyle shipmentStatusStepStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: shipmentStatusBlue,
  );

  /// Header + body for shipment status cards ("Your Shipment …" / "Your shipment …").
  static const TextStyle shipmentStatusTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: shipmentStatusBlue,
  );

  static const TextStyle shipmentStatusBodyStyle = TextStyle(
    fontSize: 14,
    color: shipmentStatusBlue,
  );
}
