import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = "Cancel",
    this.confirmText = "OK",
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    cancelText,
                    style: const TextStyle(fontSize: 16, color: AppColors.white),
                  ),
                ),

                const SizedBox(width: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm();
                  },
                  child: Text(
                    confirmText,
                    style: const TextStyle(fontSize: 16, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
