import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class CommonPinCodeField extends StatelessWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool obscureText;

  const CommonPinCodeField({
    Key? key,
    this.length = 4,
    this.obscureText = true,
    this.onChanged,
    this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Tighter spacing for 6-digit OTP so the row fits narrow screens.
        final outerPad = length > 4 ? 3.0 : 8.0;
        final cellWidth = maxWidth / length;
        final fieldWidth = (cellWidth - (outerPad * 2)).clamp(32.0, 50.0);
        final fieldHeight = length > 4
            ? (fieldWidth * 1.15).clamp(44.0, 52.0)
            : 50.0;

        return PinCodeTextField(
          appContext: context,
          length: length,
          obscureText: obscureText,
          animationType: AnimationType.fade,
          keyboardType: TextInputType.number,
          mainAxisAlignment: MainAxisAlignment.center,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(10),
            fieldHeight: fieldHeight,
            fieldWidth: fieldWidth,
            inactiveColor: AppColors.lightGrey,
            selectedColor: AppColors.secondary,
            activeColor: AppColors.lightGrey,
            activeFillColor: AppColors.white,
            selectedFillColor: AppColors.white,
            inactiveFillColor: AppColors.white,
            fieldOuterPadding: EdgeInsets.symmetric(horizontal: outerPad),
          ),
          animationDuration: const Duration(milliseconds: 300),
          enableActiveFill: true,
          onChanged: onChanged,
          onCompleted: onCompleted,
        );
      },
    );
  }
}
