import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class CommonDialog {
  /// Universal popup dialog
  static Future<void> showByType(
      BuildContext context, {
        required DialogType type,
        String? title,
        String? message,
        VoidCallback? onConfirm,
        VoidCallback? onCancel,
      }) async {
    String dialogTitle = "";
    String dialogMessage = "";
    String leftButtonText = "Cancel";
    String rightButtonText = "OK";

    switch (type) {
      case DialogType.noInternet:
        dialogTitle = "No Internet";
        dialogMessage = "Please check your internet connection.";
        rightButtonText = "Retry";
        break;

      case DialogType.deleteUser:
        dialogTitle = "Delete User";
        dialogMessage = "Do you want to delete this user?";
        rightButtonText = "Yes";
        break;

      case DialogType.exitApp:
        dialogTitle = "Exit App";
        dialogMessage = "Are you sure you want to exit?";
        rightButtonText = "Exit";
        break;

      case DialogType.logout:
        dialogTitle = "Logout";
        dialogMessage = "Are you sure you want to logout?";
        rightButtonText = "Yes";
        break;

      case DialogType.confirm:
        dialogTitle = title ?? "Confirm";
        dialogMessage = message ?? "Are you sure?";
        rightButtonText = "Yes";
        break;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(dialogTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 18)),
          content:
          Text(dialogMessage, style: const TextStyle(fontSize: 16)),

          // FIXED BUTTONS
          actions: [
            Row(
              children: [
                // Cancel
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (onCancel != null) onCancel();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor:
                      AppColors.lightGrey.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(leftButtonText,
                        style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(width: 10),

                // Confirm
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (onConfirm != null) onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      rightButtonText,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }
}

enum DialogType { noInternet, deleteUser, exitApp, logout, confirm }
