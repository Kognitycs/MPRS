import 'package:flutter/material.dart';

class AppColors {
  /// Primary brand blue (UI accent — not used for logo assets).
  static const Color main = Color(0xFF0050E6);
  static const Color secondary = Color(0xFF0050E6);
  static const Color grey = Color(0xFF5D5D5D);
  static const Color lightGrey = Color(0xFFBBBBBB);
  /// Timeline / status accent (was orange; now brand blue).
  static const Color yellow = Color(0xFF0050E6);
  static const Color main_10 = Color(0x1A0050E6);
  static const Color darkGray = Color(0xFF747996);
  /// Chart / legend secondary (light blue).
  static const Color orange = Color(0xFF6699FF);
  static const Color green = Color(0xFF34A853);
  static const Color labelBlackColor = Color(0xFF343A40);
  static const Color greyBlue = Color(0xFFC0D2F0);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color background = Colors.white;

  /// Home-screen card outline. Use with a white fill and no drop shadow.
  static const Color cardBorder = Color(0xFFE4E7EC);
  static const Color transparent = Colors.transparent;

  /// Replaces former orange-tint backgrounds (e.g. `AppColors.accentLight`).
  static const Color accentLight = Color(0xFFE8F0FE);
  static const Color accentMuted = Color(0xFFB3CCFF);
}
