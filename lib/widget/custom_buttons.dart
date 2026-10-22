
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

  const MainButton({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main, // You can modify this color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Adjusted border radius
          ),
        ),
        child: Text(
          text,
          style:  TextStyle(fontSize: 16, color: AppColors.white,fontWeight: FontWeight.bold,),
        ),
      ),
    );
  }

}

