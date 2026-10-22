import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class OutlinedRedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const OutlinedRedButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary, width: 1.2),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
