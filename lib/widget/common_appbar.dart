import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? actionWidget;
  final VoidCallback? onActionPressed;

  const CommonAppBar({
    Key? key,
    required this.title,
    this.onBack,
    this.actionWidget,
    this.onActionPressed,
  }) : super(key: key);

  void _safeBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      debugPrint("No screen to pop, ignoring back");
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBack = Navigator.canPop(context);

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 5,

      shape: const Border(
        bottom: BorderSide(color: AppColors.cardBorder, width: 1),
      ),

      // FIX: Maintain left padding even if no back button
      leadingWidth: hasBack ? 40 : 20,

      leading: hasBack
          ? Padding(
              padding: const EdgeInsets.only(left: 2),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.black, size: 20),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
                onPressed: () => _safeBack(context),
              ),
            )
          : const SizedBox(width: 20), // dummy space for left padding

      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      actions: actionWidget != null
          ? [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: OutlinedButton(
            onPressed: onActionPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.main, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: actionWidget!,
          ),
        ),
      ]
          : null,
    );
  }


  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
