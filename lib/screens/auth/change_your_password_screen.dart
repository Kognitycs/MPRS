import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/core/utils/progress_dialog.dart';
import 'package:mprs_android/core/utils/snackbar_util.dart';
import 'package:mprs_android/screens/auth/login_password_screen.dart';
import 'package:mprs_android/service/phone_auth_service.dart';
import 'package:mprs_android/widget/common_fields.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class ChangeYourPasswordScreen extends StatefulWidget {
  final String? mobileNumber;

  const ChangeYourPasswordScreen({super.key, this.mobileNumber});

  @override
  State<ChangeYourPasswordScreen> createState() =>
      _ChangeYourPasswordScreenState();
}

class _ChangeYourPasswordScreenState extends State<ChangeYourPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _newPasswordError;
  String? _confirmPasswordError;
  bool _isSubmitting = false;

  String get _mobileDigits =>
      widget.mobileNumber?.replaceAll(RegExp(r'\D'), '') ?? '';

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    String? newError;
    String? confirmError;

    if (newPassword.isEmpty) {
      newError = 'Please enter your new password';
    } else if (newPassword.length < 6) {
      newError = 'Password must be at least 6 characters';
    }

    if (confirmPassword.isEmpty) {
      confirmError = 'Please confirm your password';
    } else if (newPassword.isNotEmpty && confirmPassword != newPassword) {
      confirmError = 'Passwords do not match';
    }

    if (_mobileDigits.length != 10) {
      showSnackBar(context, 'Mobile number is missing. Please restart reset.');
      return false;
    }

    setState(() {
      _newPasswordError = newError;
      _confirmPasswordError = confirmError;
    });

    return newError == null && confirmError == null;
  }

  Future<void> _confirmPassword() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    ProgressLoader.show(context);

    try {
      final message = await _phoneAuthService.resetForgotPassword(
        mobile: _mobileDigits,
        newPassword: _newPasswordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );
      if (!mounted) return;

      showSnackBar(
        context,
        message,
        backgroundColor: AppColors.green,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPasswordScreen(mobileNumber: _mobileDigits),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      ProgressLoader.hide(context);
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Change your Password',
          style: AppTextStyles.montserratSemiBold.copyWith(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/mprs_logo.png',
                        height: 52,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Set a new password',
                      style: AppTextStyles.montserratBold.copyWith(
                        fontSize: 22,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Create a strong password and confirm it below.',
                      style: AppTextStyles.montserratRegular.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF5F6368),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    buildSignupPasswordField(
                      label: 'New Password',
                      hint: 'Enter new password',
                      controller: _newPasswordController,
                      isRequired: true,
                      obscureText: !_newPasswordVisible,
                      onTogglePassword: () => setState(
                        () => _newPasswordVisible = !_newPasswordVisible,
                      ),
                      errorText: _newPasswordError,
                      onChanged: (_) {
                        if (_newPasswordError != null) {
                          setState(() => _newPasswordError = null);
                        }
                      },
                    ),
                    buildSignupPasswordField(
                      label: 'Confirm Your Password',
                      hint: 'Re-enter new password',
                      controller: _confirmPasswordController,
                      isRequired: true,
                      obscureText: !_confirmPasswordVisible,
                      onTogglePassword: () => setState(
                        () =>
                            _confirmPasswordVisible = !_confirmPasswordVisible,
                      ),
                      errorText: _confirmPasswordError,
                      onChanged: (_) {
                        if (_confirmPasswordError != null) {
                          setState(() => _confirmPasswordError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    MainButton(
                      text: _isSubmitting ? 'Updating...' : 'Update',
                      onPressed: _isSubmitting ? () {} : _confirmPassword,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
