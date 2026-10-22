import 'package:flutter/material.dart';
import 'package:mprs_android/widget/app_loader.dart';

class Loader {
  static final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  static void show() => _isLoading.value = true;

  static void hide() => _isLoading.value = false;

  static bool get isShown => _isLoading.value;

  static Widget overlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (_, isLoading, _) {
        if (!isLoading) return const SizedBox.shrink();

        return Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black45),
            Center(child: AppLoader()),
          ],
        );
      },
    );
  }
}
