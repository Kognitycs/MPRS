
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';

class BiometricButton extends StatefulWidget {
  final VoidCallback onPressed;

  const BiometricButton({
    required this.onPressed,
    super.key,
  });

  @override
  State<BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<BiometricButton> {
  bool _isAvailable = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  void _checkBiometricAvailability() async {
    final isAvailable = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    if (mounted) {
      setState(() {
        _isAvailable = isAvailable && isDeviceSupported;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.main),
        foregroundColor: AppColors.main,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(Icons.fingerprint, size: 24, color: AppColors.main),
      label: Text(
        'Login with Biometrics',
        style: AppTextStyles.montserratBold.copyWith(fontSize: 18, color: AppColors.main),
      ),
      onPressed: widget.onPressed,
    );
  }
}

class OutlineButton extends StatefulWidget {
  final VoidCallback onPressed;

  const OutlineButton({
    required this.onPressed,
    super.key,
  });

  @override
  State<OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<OutlineButton> {

  @override
  Widget build(BuildContext context) {


    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.main),
        foregroundColor: AppColors.main,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      label: Text(
        'Manage Banner',
        style: TextStyle(fontSize: 18, color: AppColors.main),
      ),
      onPressed: widget.onPressed,
    );
  }
}


class MainButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double height;
  final double fontSize;

  const MainButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.height = 60,
    this.fontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main,
          padding:
              height < 52
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
                  : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Compact save + account actions for profile screens (sticky footer).
class ProfileStickyActions extends StatelessWidget {
  final String saveLabel;
  final VoidCallback? onSave;
  final VoidCallback onChangePassword;
  final VoidCallback? onDeleteAccount;
  final bool showDeleteAccount;
  final Color deleteColor;
  final String deleteLabel;

  const ProfileStickyActions({
    super.key,
    required this.saveLabel,
    required this.onSave,
    required this.onChangePassword,
    this.onDeleteAccount,
    this.showDeleteAccount = true,
    this.deleteColor = const Color(0xFFE53935),
    this.deleteLabel = 'Delete',
  });

  static const _outlineHeight = 40.0;
  static const _outlineRadius = 8.0;

  Widget _changePasswordButton({bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _outlineHeight,
      child: OutlinedButton.icon(
        onPressed: onChangePassword,
        icon: const Icon(Icons.lock_outline_rounded, size: 15),
        label: const Text('Change Password'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.main,
          side: const BorderSide(color: AppColors.main),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_outlineRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MainButton(
          text: saveLabel,
          onPressed: onSave ?? () {},
          height: 44,
          fontSize: 15,
        ),
        const SizedBox(height: 6),
        if (showDeleteAccount)
          Row(
            children: [
              Expanded(child: _changePasswordButton()),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: _outlineHeight,
                  child: OutlinedButton.icon(
                    onPressed: onDeleteAccount,
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label: Text(deleteLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: deleteColor,
                      side: BorderSide(color: deleteColor),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_outlineRadius),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          _changePasswordButton(fullWidth: true),
      ],
    );
  }
}

