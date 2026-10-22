import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import '../core/constants/app_colors.dart';

class RoundedInputField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final String? hint;
  final bool editable;

  const RoundedInputField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.onChanged,
    this.editable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: editable,
        readOnly: !editable,
        style:  AppTextStyles.montserratSemiBold.copyWith(
          color: Colors.black,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always, // <-- FIXED

          labelStyle: AppTextStyles.montserratRegular.copyWith(
            color: Colors.grey,
            fontSize: 16,
          ),
          filled: true,
          fillColor: AppColors.white,

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.main, width: 1.4),
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
